#!/bin/sh
# What the watcher promises: silence while nothing changes, one alert when a
# problem appears or goes away, the outcome in environment variables, and an
# exit code a timer can act on. No network, no timer, no systemd.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
MEM=${MEM_BIN:-mem}
W="$HERE/doctor-watch"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
DB="$TMP/mem.db"
BROKEN="$TMP/not-a-database.db"
LOG="$TMP/alerts.log"

failures=0
ok()   { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; failures=$((failures + 1)); }

"$MEM" --db "$DB" init >/dev/null
printf 'this is not a database\n' > "$BROKEN"
: > "$LOG"

notify="echo \"\$DOCTOR_STATUS \$DOCTOR_CHANGE \$DOCTOR_PROBLEMS\" >> $LOG"

# Healthy, first run: nothing to say, no alert, exit 0.
"$W" --mem "$MEM" --db "$DB" --state "$TMP/state.json" --on-change "$notify" > "$TMP/out1"
[ -s "$TMP/out1" ] && fail "the first healthy run printed something" || ok "a healthy first run is silent"
[ "$(wc -l < "$LOG")" = '0' ] && ok "and does not alert" || fail "a healthy first run alerted"

# Healthy again: still nothing.
"$W" --mem "$MEM" --db "$DB" --state "$TMP/state.json" --on-change "$notify" > "$TMP/out2"
[ "$(wc -l < "$LOG")" = '0' ] && ok "an unchanged run stays quiet" || fail "an unchanged run alerted again"

# A real problem: doctor exits 1, the watcher alerts once.
"$W" --mem "$MEM" --db "$BROKEN" --state "$TMP/state.json" --on-change "$notify" > "$TMP/out3"
grep -q 'problem' "$TMP/out3" && ok "a problem is printed" || fail "a problem was not printed: $(cat "$TMP/out3")"
grep -q '^bad problem 1$' "$LOG" \
  && ok "the alert gets status, change and count in the environment" \
  || fail "the alert environment is wrong: $(cat "$LOG")"

# The same problem again, with a different state file: still a first sighting,
# and still exactly one alert.
"$W" --mem "$MEM" --db "$BROKEN" --state "$TMP/state2.json" --on-change "$notify" > /dev/null
[ "$(wc -l < "$LOG")" = '2' ] && ok "a new state file alerts on the problem it finds" || fail "the second state file did not alert"

# Same problem, same state: no second alert.
"$W" --mem "$MEM" --db "$BROKEN" --state "$TMP/state2.json" --on-change "$notify" > /dev/null
[ "$(wc -l < "$LOG")" = '2' ] && ok "the same problem does not alert twice" || fail "a repeated problem alerted again"

# Recovered: one more alert, and it says so.
"$W" --mem "$MEM" --db "$DB" --state "$TMP/state2.json" --on-change "$notify" > /dev/null
grep -q '^ok recovered 0$' "$LOG" && ok "recovery is an alert of its own" || fail "recovery did not alert: $(cat "$LOG")"

# A notifier that fails must not swallow the notice: the state is not
# advanced, so the next run tries again.
if "$W" --mem "$MEM" --db "$BROKEN" --state "$TMP/state6.json" --on-change 'exit 7' > /dev/null 2>&1; then
  fail "a failing alert command exited 0"
else
  ok "a failing alert command fails the run"
fi
"$W" --mem "$MEM" --db "$BROKEN" --state "$TMP/state6.json" --on-change "$notify" > /dev/null
[ "$(wc -l < "$LOG")" = '4' ] \
  && ok "a failed alert is retried on the next run" \
  || fail "the state advanced past a failed alert"

# The exit code a timer can use.
if "$W" --mem "$MEM" --db "$BROKEN" --state "$TMP/state3.json" --fail-on-problem > /dev/null; then
  fail "--fail-on-problem exited 0 with a problem"
else
  ok "--fail-on-problem exits 1 while doctor has problems"
fi

# --verbose speaks every run, which is what a cron log wants.
out=$("$W" --mem "$MEM" --db "$DB" --state "$TMP/state4.json" --verbose)
printf '%s\n' "$out" | grep -q 'doctor: ok' && ok "--verbose prints the state even without a change" || fail "--verbose said nothing"

# A mem that is not there is not a problem to guess at.
if "$W" --mem "$TMP/nope" --db "$DB" --state "$TMP/state5.json" > /dev/null 2>&1; then
  fail "a missing binary exited 0"
else
  ok "a missing binary fails loudly instead of reporting health"
fi

if [ "$failures" -ne 0 ]; then
  printf '\n%d checks failed\n' "$failures" >&2
  exit 1
fi
printf '\nall good.\n'
