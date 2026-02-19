---
name: nix-module
description: Write idiomatic NixOS/home-manager modules
license: MIT
---

## What I do
Help write well-structured Nix modules following community conventions.

## Guidelines
- Use `mkEnableOption` for feature flags
- Use `mkOption` with proper types from `lib.types`
- Guard config with `mkIf cfg.enable`
- Use `lib.mkDefault` for overridable defaults
- Prefer `lib.optional` / `lib.optionals` over if-then-else
- Namespace options appropriately (e.g., `services.myApp`, `programs.myTool`)
- Add descriptions to all options
- Use `literalExpression` for complex examples
