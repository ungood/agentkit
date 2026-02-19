---
name: git-release
description: Create consistent releases and changelogs
license: MIT
metadata:
  audience: maintainers
  workflow: github
---

## What I do
- Draft release notes from merged PRs
- Propose a version bump based on conventional commits
- Provide a copy-pasteable `gh release create` command

## When to use me
Use this when you are preparing a tagged release.
Ask clarifying questions if the target versioning scheme is unclear.

## Steps
1. Run `git log --oneline $(git describe --tags --abbrev=0)..HEAD`
2. Categorize changes into Added, Changed, Fixed, Removed
3. Determine version bump (major/minor/patch) from commit prefixes
4. Draft the release notes in Keep a Changelog format
5. Provide the `gh release create` command
