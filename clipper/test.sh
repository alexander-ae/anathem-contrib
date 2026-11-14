#!/bin/sh
# What the clipper promises: one plain-text memory per URL, no boilerplate, the
# URL as --ext-id so a second clip writes nothing, and a draft until accepted.
# Runs against a fixture, never the network. MEM_BIN is the binary under test.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
MEM=${MEM_BIN:-mem}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
DB="$TMP/mem.db"
URL='https://example.com/k8s-eviction?utm_source=newsletter&utm_medium=email#the-three-settings'

failures=0
ok()   { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; failures=$((failures + 1)); }

"$MEM" --db "$DB" init >/dev/null

out=$("$HERE/clip" --mem "$MEM" --db "$DB" --from-file "$HERE/fixtures/article.html" \
  --url "$URL" --project reading --tag reading)
printf '%s\n' "$out" | grep -q 'saved as a draft' \
  && ok "the first clip leaves a draft" \
  || fail "the first clip did not say it left a draft: $out"

# The checks are on the body: that is what a person will read in the terminal.
body=$("$MEM" --db "$DB" show 1 --json | jq -r .body)

printf '%s\n' "$body" | head -1 | grep -q '^Kubernetes eviction, in practice$' \
  && ok "the first line is the page title" \
  || fail "the first line is not the title: $(printf '%s' "$body" | head -1)"

printf '%s\n' "$body" | grep -q 'What the eviction manager actually does' \
  && ok "the meta description travels" \
  || fail "the meta description is missing"

printf '%s\n' "$body" | grep -q '^source: https://example.com/k8s-eviction$' \
  && ok "the canonical URL is recorded and tracking parameters are gone" \
  || fail "the source line is wrong: $(printf '%s\n' "$body" | grep '^source:')"

printf '%s\n' "$body" | grep -q 'ranks every pod by the quality of service' \
  && ok "the article text is there" \
  || fail "the article text is missing"

printf '%s\n' "$body" | grep -q '^## The three settings that matter$' \
  && ok "headings stay headings, so anathem's outline setting can read them" \
  || fail "the h2 did not survive as a markdown heading"

printf '%s\n' "$body" | grep -q 'SHOULD NOT APPEAR' \
  && fail "boilerplate survived: nav, cookie banner, footer or script" \
  || ok "no nav, banner, footer or script text"

[ "$("$MEM" --db "$DB" show 1 --json | jq -r .ext_id)" = 'https://example.com/k8s-eviction' ] \
  && ok "the id is the canonical URL, so the delivery is idempotent" \
  || fail "the ext_id is not the canonical URL"

[ "$("$MEM" --db "$DB" show 1 --json | jq -r .status)" = 'draft' ] \
  && ok "it is a draft, invisible to search" \
  || fail "the memory is not a draft"

[ "$("$MEM" --db "$DB" search eviction --json | jq '.results | length')" = '0' ] \
  && ok "a draft does not answer a search" \
  || fail "the draft is already searchable before being accepted"

# The same page through another tracking link: nothing new.
out=$("$HERE/clip" --mem "$MEM" --db "$DB" --from-file "$HERE/fixtures/article.html" \
  --url 'https://example.com/k8s-eviction?fbclid=abc' --project reading)
printf '%s\n' "$out" | grep -q 'already clipped: id 1' \
  && ok "a second clip writes nothing and names the existing id" \
  || fail "the second clip did not report the existing memory: $out"

[ "$("$MEM" --db "$DB" recent --all --external --json | jq '.items | length')" = '1' ] \
  && ok "still one memory after two clips" \
  || fail "the retry duplicated the memory"

# Accepting is what lets it in.
"$MEM" --db "$DB" accept 1 >/dev/null
[ "$("$MEM" --db "$DB" search eviction --json | jq '.results | length')" = '1' ] \
  && ok "after accept, the search finds it" \
  || fail "the search does not find the accepted memory"

# --accept does both in one call.
"$HERE/clip" --mem "$MEM" --db "$DB" --from-file "$HERE/fixtures/article.html" \
  --url 'https://example.com/another-page' --project reading --accept >/dev/null
[ "$("$MEM" --db "$DB" search "another page" --json | jq '.results | length')" -ge 1 ] \
  && ok "--accept files and accepts in one call" \
  || fail "--accept left it as a draft"

if [ "$failures" -ne 0 ]; then
  printf '\n%d checks failed\n' "$failures" >&2
  exit 1
fi
printf '\nall good.\n'
