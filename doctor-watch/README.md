# doctor-watch

Runs `mem doctor --json` on a timer and alerts **only when the answer
changes**: a problem appeared, the set of problems changed, or everything came
back. A run every fifteen minutes is therefore silent all day and one line
when it matters.

`mem doctor` was already the thing to check; what was missing was something
that checks it without a person remembering to.

## Install

Copy `doctor-watch` somewhere on `PATH` and add the timer:

```sh
cp doctor-watch ~/.local/bin/
mkdir -p ~/.config/systemd/user
cp systemd/anathem-doctor.{service,timer} ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now anathem-doctor.timer
```

The service starts with no `--on-change`, so the first version only writes to
the journal (`journalctl --user -u anathem-doctor`). Add a command to the
unit to be told, or run it from cron.

## Usage

```sh
doctor-watch --on-change 'ntfy publish anathem "$DOCTOR_MESSAGE"'
doctor-watch --db ~/.anathem/mem.db --verbose
doctor-watch --fail-on-problem   # a timer marks the unit failed
```

| flag | what it does |
|---|---|
| `--mem <path>` | the binary (default: `$MEM_BIN` or `mem`) |
| `--db <path>` | passed through to `mem --db` |
| `--state <path>` | where the last result is kept (default: `~/.local/state/anathem/doctor-watch.json`) |
| `--on-change <cmd>` | shell command run on a change; reads the variables below |
| `--timeout <s>` | how long to wait for `mem doctor` (default: 90) |
| `--verbose` | print the state every run, not only on a change |
| `--fail-on-problem` | exit 1 while doctor has problems |

## What the alert command receives

| variable | value |
|---|---|
| `DOCTOR_STATUS` | `ok` or `bad` |
| `DOCTOR_CHANGE` | `problem`, `recovered` or `first-bad` |
| `DOCTOR_PROBLEMS` | how many problems |
| `DOCTOR_WARNINGS` | how many warnings |
| `DOCTOR_DATABASE` | the database doctor looked at |
| `DOCTOR_MESSAGE` | one line, ready to send |
| `DOCTOR_FINDINGS` | every bad finding, one per line |

The command is run by a shell and the values arrive only as environment
variables, never interpolated into it: the findings contain text anathem
stored, and a note should not be able to become part of a command line.

## Examples

```sh
# ntfy
doctor-watch --on-change 'ntfy publish anathem "$DOCTOR_MESSAGE"'

# a note to another machine, through stele
doctor-watch --on-change 'stele send --to laptop --project infra "$DOCTOR_MESSAGE"'

# a file, for whoever reads it later
doctor-watch --on-change 'printf "%s\n%s\n" "$(date -Is)" "$DOCTOR_FINDINGS" >> ~/anathem-doctor.log'
```

## Exit codes

| code | meaning |
|---|---|
| 0 | the check ran, whether or not it found problems |
| 1 | `--fail-on-problem` and doctor has problems, or the alert command failed |
| 2 | usage |

A `mem` that is missing, hangs or answers with something that is not JSON is a
loud failure, not a silent "all good": a monitor that reports health it could
not check is worse than no monitor.

## Limits

- **One state file per database.** Watching two databases with the same state
  file makes them overwrite each other; pass `--state` for the second.
- **The state lives in a file, not in anathem.** `doctor-watch` never writes
  to the database: that would be the diagnostic modifying what it diagnoses.
- **It only tells you.** Nothing is repaired; the finding names the command.
- **A fingerprint is the bad findings, not history.** Two different problems
  alert; the same problem twice does not.
