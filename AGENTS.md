# Agents

Instructions for AI coding agents working on this project.

## Overview

agentkit is a Nix flake-parts module system for composing AI agent
configuration. It defines skills (Agent Skills spec directories) and
commands (slash-command templates), then deploys them to agent runtimes
like OpenCode via runtime adapters.

## Architecture

- **`lib/types.nix`** -- Skill and command type definitions
- **`modules/flake-module.nix`** -- Core module: options, devshell aggregation
- **`modules/runtimes/`** -- Runtime adapters (one per agent runtime)
- **`modules/skills/`** -- Built-in skill modules (home-manager pattern)
- **`tests/default.nix`** -- Test suite run via `nix flake check`

## Conventions

- All Nix code is formatted with `nixfmt` and linted with `deadnix`/`statix`.
  Run `nix fmt` or `just format` before committing.
- Skills follow the [Agent Skills specification](https://agentskills.io/specification).
- Skill modules follow the home-manager program module pattern: `enable`
  option (flake-level), `package` option (per-system), contributes to
  `agentkit.devshell.packages` when enabled.
- Option paths are namespaced: `agentkit.runtimes.<name>` for runtimes,
  `agentkit.skills.<name>` for skill modules.

## Testing

```sh
just check    # or: nix flake check
just test     # verbose output: nix flake check -L
```

Tests verify skill directory copying and command frontmatter rendering.