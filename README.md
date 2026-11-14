# anathem-contrib

Integrations for [anathem](https://gitlab.com/__alexander__/anathem): separate
programs that call `mem` and read its `--json`. Nothing here is loaded by the
binary — anathem has no plugin runtime, and that is a decision, not a gap.

Each folder is self-contained: its code, its README, its tests, its own
dependencies. There is no shared library on purpose; coupling is what makes a
change in one folder break another.

## What is here

| integration | what it does | needs |
|---|---|---|
| [`clipper/`](clipper/) | a web page as a plain-text draft, one per URL | `mem` 1.1+, `python3`, `jq` (tests only) |

## What is not here

- **stele** is not a contrib. It is a mailbox between machines with its own
  repository, release and service; it speaks the same contract from outside,
  and it is the reason `--ext-id` exists.
- **No runtime.** Nothing here is imported or executed by `mem`. An
  integration is installed by copying it somewhere on `PATH`.
- **No capture without a person.** Nothing here saves on its own: a draft
  waits for `mem accept`.

## Running the tests

Each folder has a `test.sh` that runs against a temporary database:

```sh
MEM_BIN=/path/to/mem ./run-all.sh
```

## The contract

[`docs/integrations.md`](https://gitlab.com/__alexander__/anathem/-/blob/main/docs/integrations.md)
in the anathem repository, schema 1. A field may be added without a version
bump; a field may not change meaning without one.

## License

MIT. See [LICENSE](LICENSE).
