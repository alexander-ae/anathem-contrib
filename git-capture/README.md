# git-capture

A `post-commit` hook that turns the reason behind a commit into a memory — but
only when the commit says why:

```
fix(api): use Adyen for card payments

Why: the old provider dropped webhooks silently and we lost three refunds
before anybody noticed.
Topic: payment-provider
```

A commit without a `Why:` trailer writes nothing. That is the design: a hook
that captures every commit is the noise anathem exists to avoid.

## Install

```sh
git-capture install      # in the repository
git-capture uninstall    # removes only its own block
```

If a `post-commit` hook already exists, the block is **appended**, not
replaced; both run.

## What it stores

```
fix(api): use Adyen for card payments

the old provider dropped webhooks silently and we lost three refunds before
anybody noticed.

commit 051ad72c40b349f303804ac831193e9be3ffc092
branch main
files 3 changed (src/pay.rs, src/api.rs, +1)
```

- The commit subject is the title.
- The **full** commit id is in the body because anathem extracts it as a
  `sha` ref: from there it is one hop back to the commit.
- The project comes from the repository; no flag, no configuration.

## Trailers

| trailer | effect |
|---|---|
| `Why:` | required. No trailer, no memory |
| `Topic:` | optional. Replaces the previous active memory under that key |

Only the **last paragraph** of the message is read, which is where git keeps
trailers; a `Why:` inside the body prose is not one. Continuation lines are
indented.

## Environment

| variable | what it changes |
|---|---|
| `MEM_BIN` | the binary (default: `mem` on `PATH`) |
| `ANATHEM_DB` | the database (default: what `mem` uses) |

The hook inherits the environment and takes no arguments, so those are how it
finds the binary and the database on a machine where they are not the default.

## Limits

- **No diff.** A memory is the reason, not the change; `git show` has the
  diff.
- **Amending is a new commit.** It gets a new id and therefore a new memory.
- **One capture per commit.** The id of the last one is kept in
  `.git/anathem-capture`, so running the hook again does not duplicate;
  `--force` repeats it on purpose.
- **Quiet on machines without the tool.** The hook checks `command -v` and
  does nothing there, so a clone keeps working anywhere.

## Commands

| command | what it does |
|---|---|
| `install` / `uninstall` | add or remove the hook |
| `run` | capture `HEAD`; this is what the hook calls |
| `run --dry-run` | print the memory it would save |
| `run --force` | capture `HEAD` even if it was already captured |

Global flags go before the subcommand: `git-capture --repo ~/code/api run`.

## Tests

```sh
MEM_BIN=/path/to/mem ./test.sh
```

Twenty checks: nothing without the trailer, one memory per commit, the project
guessed from the repository, the `sha` ref, `Topic:` replacing, the dedupe and
`--force`, `--dry-run`, an existing hook preserved and still running, and
`uninstall` leaving the rest of it alone.
