# clipper

A web page as a memory: title, meta description, source URL, fetch date, and
the article in plain text. It arrives as an external draft, invisible to
search until accepted, which is what makes it a read-later queue:

```sh
clip https://example.com/article
mem recent --all --external   # the queue
mem accept 42                 # read it
```

## Install

Copy `clip` somewhere on `PATH`, for example `~/.local/bin`. Standard library
only: no pip, no virtualenv.

## What it stores

```
<page title>
<meta description>            (when the page has one)

source: <canonical URL>
fetched: YYYY-MM-DD

---

## headings, lists, quotes and code, as markdown
<p>the article text</p>
```

The canonical URL is also the anathem `--ext-id`, so clipping the same page
twice writes one memory. Tracking parameters (`utm_*`, `fbclid`, …) and the
fragment are removed first.

## Flags

| flag | what it does |
|---|---|
| `--project <p>` | anathem project (default: `reading`) |
| `--tag <t>` | repeatable (default: `reading`) |
| `--from <label>` | the sender anathem records (default: `clipper`) |
| `--accept` | accept it now instead of leaving it as a draft |
| `--max-chars <n>` | text to keep (default: 10000) |
| `--db <path>` | passed through to `mem --db` |
| `--mem <path>` | the binary (default: `$MEM_BIN` or `mem`) |
| `--from-file <html>` | extract from a file instead of the network, with `--url` |

## Limits

- **The extractor is a heuristic.** It picks the densest of `<article>`,
  `<main>` and the block elements, discounting link-heavy blocks. It will lose
  some pages; `extract()` is one function, so replacing it is local.
- **No JavaScript.** A page built in the browser yields no text, and nothing
  is saved — the command says so and exits 1.
- **No refresh.** The `--ext-id` dedupes forever, so an updated page is not
  picked up by clipping it again.
- **Truncated at 10,000 characters** by default, at a paragraph boundary, and
  the body says how much was left out.

## Tests

```sh
MEM_BIN=/path/to/mem ./test.sh
```

Against `fixtures/article.html`: no network, and it checks the body, the
canonical id, that a draft is not searchable, and that a retry writes nothing.
