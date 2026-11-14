# mem-pick

A numbered picker over a search or the inbox, for the moment after the search:
you know which one it is, and you want its body or its id without typing
`mem show 31`.

```
   #  id  project  matched  title
   1  1   api      2/2      The payment provider is Adyen since October
   2  7   web      1/2      Adyen integration notes for the web checkout
pick [1-2, q]:
```

The menu is written to **stderr** and the answer to **stdout**, so it composes
without parsing anything:

```sh
mem show $(mem-pick "payment provider" --action id)
id=$(mem-pick --recent --external --action id) && mem accept "$id"
```

No `fzf`: a numbered list needs nothing installed and works over SSH.

## Install

Copy `mem-pick` somewhere on `PATH`. Python 3 standard library only.

## Usage

```sh
mem-pick "payment provider"            # body on a terminal, id in a pipe
mem-pick --recent --external           # the inbox, drafts marked
mem-pick --action id "cache" | xargs mem show
```

| flag | what it does |
|---|---|
| `--recent` | list what was saved lately instead of searching |
| `--external` | with `--recent`: the inbox, drafts included |
| `--project <p>` | narrow the listing |
| `--limit <n>` | how many to list (default: 10) |
| `--action body\|id\|title` | what to print (default: body on a terminal, id otherwise) |
| `--pick <n>` | choose without prompting |
| `--db <path>` | passed through to `mem --db` |
| `--mem <path>` | the binary (default: `$MEM_BIN` or `mem`) |

The `matched` column is `words_matched/words_total`, the same number behind
anathem's `[no word match]` label: `0/3` means the ranking answered without a
word of the query landing, and it is worth a second look before opening it.

## Limits

- **No preview.** The title and the match count, not the body; opening one is
  the way to read it.
- **No fuzzy filtering.** If the list is not the one you wanted, the query is
  the thing to change.
- **No terminal and no `--pick` is an error**, not a prompt: a script that
  forgot the flag should fail rather than wait on a pipe.

## Tests

```sh
MEM_BIN=/path/to/mem ./test.sh
```

Eleven checks: the menu on stderr and only the answer on stdout, the id fed
back to `mem show`, body and title modes, the pipe default, drafts marked in
the inbox, an empty search, a missing terminal, and an out-of-range pick.
