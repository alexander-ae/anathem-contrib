#!/bin/sh
# Runs every integration's test.sh. MEM_BIN is the anathem binary under test.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
MEM_BIN=${MEM_BIN:-mem}
command -v "$MEM_BIN" >/dev/null 2>&1 || {
  printf 'MEM_BIN=%s is not executable\n' "$MEM_BIN" >&2
  exit 2
}
# Absolute, because a hook runs in another directory: `MEM_BIN=./mem` works
# from here and would not from the temporary repository git-capture creates.
MEM_BIN=$(command -v "$MEM_BIN")
case "$MEM_BIN" in
  */*) MEM_BIN=$(cd "$(dirname "$MEM_BIN")" && pwd)/$(basename "$MEM_BIN") ;;
esac

failed=0
for test in "$HERE"/*/test.sh; do
  [ -e "$test" ] || continue
  name=$(basename "$(dirname "$test")")
  printf '\n== %s\n' "$name"
  MEM_BIN="$MEM_BIN" "$test" || failed=$((failed + 1))
done

if [ "$failed" -ne 0 ]; then
  printf '\n%d integration(s) failed\n' "$failed" >&2
  exit 1
fi
