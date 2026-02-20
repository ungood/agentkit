# TODO

## Reconcile Nix code with README examples

The README was updated to reflect the desired API. The underlying Nix code
and docs need to be updated to match. Key discrepancies:

### Option renames

- **`skills.<name>.path`** -- README uses `path`, code uses `directory`.
  Rename the option in `lib/types.nix`, all runtime adapters, skill modules,
  examples, tests, and `docs/authoring-modules.md`.

### New features

- **`skills.<name>.packages`** -- README shows inline skills declaring
  `packages = [ pkgs.lolcat ];`. The code has no `packages` field on the
  skill type. Need to add per-skill package lists (per-system) and merge
  them into `agentkit.devshell.packages`. Note: `pkgs` is referenced at
  flake-level in the README examples, so the implementation needs to handle
  the flake-level/per-system split (possibly via `perSystem` option on the
  skill type or deferred evaluation).
- **Simplified devshell** -- README devshell example has no `perSystem`
  block or explicit `agentkit.runtimes.opencode.devshell.enable`. Implies
  the devshell wiring should be automatic when a runtime is enabled.
  Evaluate whether the `perSystem` boilerplate can be eliminated entirely.
- **Unified skill shape** -- README shows both `skills.tldr.enable = true`
  (module) and `skills.lolcat = { packages = [...]; path = ./...; }`
  (inline) using the same `agentkit.skills` namespace. Ensure the skill
  submodule type supports both patterns cleanly.

### Flake exports

- **`homeModules.default`** -- README uses `homeModules.default`, code
  exports `homeModules.opencode`. Either rename or add an alias. The
  home-manager module should probably also support `agentkit.skills` with
  `enable`/`path`/`packages` like the devshell path does, rather than just
  raw `attrsOf path`.
- **Built-in skills in `flakeModules.default`** -- README imports only
  `flakeModules.default` but enables `skills.tldr.enable = true`. This
  implies built-in skills (tldr) should be included in the default flake
  module rather than exported separately as `flakeModules.tldr`. Either
  bundle them into `flakeModules.default` or re-export them automatically.

### Docs

- **`docs/authoring-modules.md`** -- Uses `directory` throughout (option
  name, mapping table, code examples). Needs updating to `path` once the
  code is changed. The "How consumers use" example still shows `perSystem`
  boilerplate which should be simplified to match the README.
