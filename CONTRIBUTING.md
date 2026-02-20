# Contributing to agentkit

## Development setup

```sh
nix develop
```

## Common tasks

```sh
just check     # Run nix flake check (includes tests)
just format    # Format with nixfmt, deadnix, statix
just test      # Run tests with verbose output
just update    # Update flake inputs
```

## Code formatting

This project uses [treefmt-nix](https://github.com/numtide/treefmt-nix) with:
- **nixfmt** -- Nix code formatting
- **deadnix** -- dead code detection
- **statix** -- anti-pattern linting

A pre-commit hook runs `treefmt` automatically. To format manually:

```sh
nix fmt
```

## Project layout

```
lib/types.nix              # Framework-agnostic skill and command types
modules/flake-module.nix   # Core flake-parts module
modules/runtimes/          # Runtime adapters (opencode, ...)
modules/skills/            # Built-in skill modules (tldr, ...)
examples/                  # Example flakes
tests/                     # nix flake check test suite
docs/                      # Documentation
```

## Adding a runtime adapter

Runtime adapters live in `modules/runtimes/<name>/`. Each adapter:
1. Filters skills by compatibility
2. Renders commands to the runtime's expected format
3. Registers itself in the per-system devshell aggregator

See `modules/runtimes/opencode/` for the reference implementation.

## Adding a skill module

Skill modules live in `modules/skills/<name>/` and follow the home-manager
program module pattern. See [docs/authoring-modules.md](docs/authoring-modules.md)
for the full guide and `modules/skills/tldr/` for a reference implementation.
