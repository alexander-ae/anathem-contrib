#!/bin/sh
# What git-capture promises: nothing without a `Why:` trailer, one memory per
# commit, `Topic:` replacing the previous note, a hook that does not clobber
# the one that was there, and a re-run that does not duplicate.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
MEM=$(command -v "${MEM_BIN:-mem}") || {
  printf 'MEM_BIN=%s is not executable\n' "${MEM_BIN:-mem}" >&2
  exit 2
}
# Absolute: the hook runs inside the temporary repository, where a relative
# path would point at nothing.
case "$MEM" in
  */*) MEM=$(cd "$(dirname "$MEM")" && pwd)/$(basename "$MEM") ;;
esac
CAP="$HERE/git-capture"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
DB="$TMP/mem.db"
REPO="$TMP/api-monolito"

failures=0
ok()   { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; failures=$((failures + 1)); }

count() { "$MEM" --db "$DB" recent --all --json | jq '.items | length'; }
commit() { git -C "$1" commit -q --allow-empty -m "$2" >/dev/null 2>&1; }

mkdir -p "$REPO"
git init -q "$REPO"
git -C "$REPO" config user.email test@example.com
git -C "$REPO" config user.name "Test"

"$MEM" --db "$DB" init >/dev/null
# The hook inherits the environment, not arguments: these are how it finds the
# binary and the database during the test.
export MEM_BIN="$MEM" ANATHEM_DB="$DB"
PATH="$HERE:$PATH"; export PATH

"$CAP" --repo "$REPO" install >/dev/null
[ -x "$REPO/.git/hooks/post-commit" ] && ok "install writes an executable hook" || fail "no hook"
"$CAP" --repo "$REPO" install | grep -q 'already installed' \
  && ok "install is idempotent" || fail "install ran twice"
[ "$(grep -c 'git-capture >>>' "$REPO/.git/hooks/post-commit")" = '1' ] \
  && ok "one managed block, not two" || fail "the block was duplicated"
[ "$(head -1 "$REPO/.git/hooks/post-commit")" = '#!/bin/sh' ] \
  && ok "the hook starts with a shebang" || fail "the hook has no shebang"
[ "$(grep -c '^#!' "$REPO/.git/hooks/post-commit")" = '1' ] \
  && ok "and only one" || fail "the shebang was duplicated"

# A commit that does not say why is not memory.
commit "$REPO" "chore: touch a file"
[ "$(count)" = '0' ] && ok "a commit with no Why: writes nothing" || fail "a plain commit was captured"

# A commit that does say why is.
out=$(git -C "$REPO" commit -q --allow-empty -m "fix(api): use Adyen" \
  -m "Why: the old provider dropped webhooks silently and we lost three refunds." 2>&1)
printf '%s\n' "$out" | grep -q 'git-capture: memory' && ok "the hook reports what it saved" || fail "the hook said nothing"
body=$("$MEM" --db "$DB" show 1 --json | jq -r .body)
printf '%s\n' "$body" | head -1 | grep -q '^fix(api): use Adyen$' && ok "the subject is the title" || fail "wrong title"
printf '%s\n' "$body" | grep -q 'dropped webhooks silently' && ok "the Why: travels" || fail "the why is missing"
sha=$(git -C "$REPO" rev-parse HEAD)
printf '%s\n' "$body" | grep -q "^commit $sha$" && ok "the full commit id is in the body" || fail "no commit id"
[ "$("$MEM" --db "$DB" show 1 --json | jq -r .project)" = 'api-monolito' ] \
  && ok "the project comes from the repository, with no flag" || fail "wrong project"
[ "$(sqlite3 "$DB" "select count(*) from memory_refs where memory_id = 1 and kind = 'sha'")" = '1' ] \
  && ok "anathem extracted the commit as a sha ref" || fail "no sha ref"

# A second run of the same commit does nothing; --force is the way to repeat.
"$CAP" --repo "$REPO" run >/dev/null
[ "$(count)" = '1' ] && ok "re-running the hook does not duplicate" || fail "the same commit was captured twice"
"$CAP" --repo "$REPO" run --force >/dev/null
[ "$(count)" = '2' ] && ok "--force captures it again" || fail "--force did nothing"

# Topic: the note replaces the previous one for that subject.
git -C "$REPO" commit -q --allow-empty -m "feat(api): Adyen is live" \
  -m "Why: the migration finished ahead of schedule.
Topic: payment-provider" >/dev/null 2>&1
git -C "$REPO" commit -q --allow-empty -m "fix(api): Adyen retries" \
  -m "Why: a failed capture left the order unpaid.
Topic: payment-provider" >/dev/null 2>&1
topic=$("$MEM" --db "$DB" topics --json | jq -c '.topics[] | select(.topic == "payment-provider")')
printf '%s' "$topic" | jq -e '.memories == 2' >/dev/null \
  && ok "Topic: versions the note instead of piling up" || fail "the topic did not version: $topic"
printf '%s' "$topic" | jq -e '.current != null' >/dev/null \
  && ok "and leaves one current version" || fail "no current version"

# --dry-run shows without writing.
before=$(count)
"$CAP" --repo "$REPO" run --dry-run | grep -q '^commit [0-9a-f]\{40\}$' \
  && ok "--dry-run prints the body it would save" || fail "--dry-run printed nothing useful"
[ "$(count)" = "$before" ] && ok "--dry-run writes nothing" || fail "--dry-run saved a memory"

# An existing hook is preserved, not replaced.
OTHER="$TMP/other"
mkdir -p "$OTHER"
git init -q "$OTHER"
git -C "$OTHER" config user.email test@example.com
git -C "$OTHER" config user.name "Test"
printf '#!/bin/sh\necho original-hook-ran\n' > "$OTHER/.git/hooks/post-commit"
chmod +x "$OTHER/.git/hooks/post-commit"
"$CAP" --repo "$OTHER" install >/dev/null
out=$(git -C "$OTHER" commit -q --allow-empty -m "feat: keep my hook" -m "Why: the file was already there." 2>&1)
printf '%s\n' "$out" | grep -q 'original-hook-ran' \
  && ok "the hook that was there still runs" || fail "the existing hook was clobbered"
printf '%s\n' "$out" | grep -q 'git-capture: memory' \
  && ok "and the capture still happens" || fail "the capture did not run alongside it"

# Uninstall takes only its own block.
"$CAP" --repo "$OTHER" uninstall >/dev/null
grep -q 'git-capture' "$OTHER/.git/hooks/post-commit" 2>/dev/null \
  && fail "uninstall left the block" || ok "uninstall removes the block"
grep -q 'original-hook-ran' "$OTHER/.git/hooks/post-commit" \
  && ok "uninstall leaves the rest of the hook" || fail "uninstall removed somebody else's hook"

if [ "$failures" -ne 0 ]; then
  printf '\n%d checks failed\n' "$failures" >&2
  exit 1
fi
printf '\nall good.\n'
