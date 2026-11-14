#!/bin/sh
# What the picker promises: a numbered menu on stderr, one answer on stdout,
# and the same answer whether a person picked it or --pick did.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
MEM=${MEM_BIN:-mem}
PICK="$HERE/mem-pick"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
DB="$TMP/mem.db"

failures=0
ok()   { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; failures=$((failures + 1)); }

"$MEM" --db "$DB" init >/dev/null
"$MEM" --db "$DB" save "The payment provider is Adyen since October" --project api --tag decision >/dev/null
"$MEM" --db "$DB" save "Adyen integration notes for the web checkout" --project web >/dev/null
"$MEM" --db "$DB" save "The cache is rebuilt nightly at 03:00" --project api >/dev/null

# stdout is the answer and nothing else: the menu goes to stderr.
out=$("$PICK" --mem "$MEM" --db "$DB" --pick 1 --action id "payment provider" 2>"$TMP/menu")
printf '%s' "$out" | grep -Eq '^[0-9]+$' && ok "id mode prints only the id" || fail "id mode printed: $out"
grep -q 'title' "$TMP/menu" && ok "the menu is on stderr" || fail "the menu was not printed"
grep -q '2/2' "$TMP/menu" && ok "the menu shows how much of the query each result holds" || fail "no matched column"

# It composes, which is the point.
id=$("$PICK" --mem "$MEM" --db "$DB" --pick 1 --action id "payment provider" 2>/dev/null)
"$MEM" --db "$DB" show "$id" --json | jq -r .title | grep -q '^The payment provider is Adyen' \
  && ok "the id it prints can be fed back to mem" \
  || fail "the id does not point at the result the menu showed"

# Body and title.
"$PICK" --mem "$MEM" --db "$DB" --pick 1 --action body "payment provider" 2>/dev/null | grep -q 'Adyen since October' \
  && ok "body mode prints the memory" || fail "body mode printed nothing useful"
[ "$("$PICK" --mem "$MEM" --db "$DB" --pick 2 --action title "Adyen" 2>/dev/null)" = 'Adyen integration notes for the web checkout' ] \
  && ok "title mode prints the title" || fail "title mode printed the wrong thing"

# Piped with no --action: id, because a pipe is not a person reading.
[ "$("$PICK" --mem "$MEM" --db "$DB" --pick 1 "cache" 2>/dev/null)" -gt 0 ] 2>/dev/null \
  && ok "a pipe defaults to the id" || fail "a pipe did not default to the id"

# The inbox, drafts marked.
"$MEM" --db "$DB" save "A note from elsewhere" --external --from laptop --project api >/dev/null
menu=$("$PICK" --mem "$MEM" --db "$DB" --recent --external --pick 1 --action id 2>&1 >/dev/null)
printf '%s\n' "$menu" | grep -q '\[draft\]' && ok "the inbox marks drafts" || fail "the inbox does not mark drafts"

# Nothing to pick is an answer, not a crash.
if "$PICK" --mem "$MEM" --db "$DB" --pick 1 "nothing matches this" >/dev/null 2>&1; then
  fail "an empty search exited 0"
else
  ok "an empty search exits 1"
fi

# No terminal and no --pick: say so instead of waiting on a pipe.
if printf '' | "$PICK" --mem "$MEM" --db "$DB" "payment" >/dev/null 2>&1; then
  fail "no terminal and no --pick exited 0"
else
  ok "no terminal and no --pick exits non-zero"
fi

if "$PICK" --mem "$MEM" --db "$DB" --pick 0 "payment" >/dev/null 2>&1; then
  fail "--pick 0 was accepted"
else
  ok "--pick out of range is rejected"
fi

if [ "$failures" -ne 0 ]; then
  printf '\n%d checks failed\n' "$failures" >&2
  exit 1
fi
printf '\nall good.\n'
