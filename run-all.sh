#!/bin/sh
# Runs every integration's test.sh. MEM_BIN is the anathem binary under test.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
MEM_BIN=${MEM_BIN:-mem}
command -v "$MEM_BIN" >/dev/null 2>&1 || {
  printf 'MEM_BIN=%s is not executable\n' "$MEM_BIN" >&2
  exit 2
}

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
