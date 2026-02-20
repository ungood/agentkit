---
name: tldr
description: Look up concise command-line tool usage with tldr pages
---

## When to use

Use `tldr` whenever you encounter an unfamiliar command-line tool or need a
quick reminder of common usage patterns. Prefer `tldr` over guessing at flags
or inventing syntax -- it provides community-maintained, example-driven
summaries that are more concise than man pages.

## Usage

```sh
# Look up a command
tldr <command>

# Look up a subcommand
tldr <command>-<subcommand>   # e.g., tldr git-rebase

# Update the local page cache
tldr --update
```

## Guidelines

- **Before using an unfamiliar tool**, run `tldr <tool>` to check common
  invocations. This avoids incorrect flag usage and saves debugging time.
- **When composing shell pipelines**, use `tldr` to verify the flags of each
  tool in the chain rather than relying on memory.
- **If `tldr` has no page** for a command, fall back to `<command> --help` or
  `man <command>`.
- **Do not run `tldr --update`** unless pages appear stale or a lookup returns
  "page not found" for a tool you know exists.
