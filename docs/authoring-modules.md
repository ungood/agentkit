# Authoring agentkit modules

This guide covers how to create agentkit modules -- Nix flakes that export
skills and commands for AI coding agents.

## Module pattern

agentkit modules follow the same pattern as
[home-manager program modules](https://nix-community.github.io/home-manager/):
each module provides an `enable` option, optional configuration (like
`package`), and wires everything up internally when enabled.

```
home-manager                            agentkit
──────────────                          ────────
programs.git.enable                →    agentkit.skills.<name>.enable
programs.git.package               →    agentkit.skills.<name>.package
home.packages += [pkg]             →    agentkit.skills.<name>.packages += [pkg]
xdg.configFile.xxx                 →    agentkit.skills.<name>.path
```

When a user imports your module and sets `enable = true`, the module:
1. Registers the skill directory
2. Adds tool packages to the skill's `packages` (auto-aggregated into the devshell)

Users don't need to manually define skill directories or add packages --
the module handles it.

## Example: the built-in tldr module

The `tldr` module that ships with agentkit is a reference implementation.
Here it is in full:

```nix
# modules/skills/tldr/default.nix
{ lib, ... }:
{
  options.perSystem = lib.mkPerSystemOption ({ lib, config, pkgs, ... }:
    let
      cfg = config.agentkit.skills.tldr;
    in
    {
      options.agentkit.skills.tldr = {
        package = lib.mkPackageOption pkgs "tealdeer" { };
      };

      # Opt-in: override the skill type's default (true) to false
      config.agentkit.skills.tldr.enable = lib.mkDefault false;

      # When enabled, set the skill path and packages
      config.agentkit.skills.tldr.path = lib.mkIf cfg.enable ./skill;
      config.agentkit.skills.tldr.packages = lib.mkIf cfg.enable [
        cfg.package
      ];
    }
  );
}
```

Key points:

- **`enable` lives in the skill submodule** -- `agentkit.skills` is an
  `attrsOf skill`, and every skill has an `enable` option (defaults `true`
  for manual skills). Modules set `mkDefault false` to make themselves opt-in.
- **`package` is a configurable option** for overriding the default tool.
- **`packages` on the skill** declares the tool dependencies. These are
  automatically aggregated into the devshell (analogous to `home.packages`
  in home-manager).
- **`path`** is set conditionally with `mkIf` when the skill is enabled.
- **Everything is in `perSystem`** so `pkgs` is available for package
  declarations.

The corresponding skill directory:

```
modules/skills/tldr/
├── default.nix           # Module definition (above)
└── skill/
    └── SKILL.md          # Agent Skills spec file
```

Users enable it like this (tldr is bundled with agentkit, so no extra import
is needed):

```nix
imports = [
  inputs.agentkit.flakeModules.default
];

perSystem = { config, pkgs, ... }: {
  agentkit = {
    enable = true;
    runtimes.opencode.enable = true;
    skills.tldr.enable = true;
  };

  devShells.default = pkgs.mkShell {
    inputsFrom = [ config.agentkit.devshell.shell ];
  };
};
```

## Creating a skill

Skills follow the [Agent Skills specification](https://agentskills.io/specification).
Each skill is a directory containing a `SKILL.md` file with YAML frontmatter.

### Directory structure

```
skill/
├── SKILL.md          # Required: YAML frontmatter + markdown instructions
├── scripts/          # Optional: executable scripts the agent can run
├── references/       # Optional: reference documents for additional context
└── assets/           # Optional: images, data files, etc.
```

### SKILL.md format

```markdown
---
name: my-skill
description: Short description of what this skill does
license: MIT
---

## When to use

Describe when the agent should apply this skill.

## Instructions

The main content of the skill. This is what the agent sees when it
loads the skill. Be specific and actionable.
```

**Required fields:**
- `name` -- lowercase alphanumeric with single hyphen separators (e.g., `git-release`)
- `description` -- a brief summary used by agents to decide whether to load the skill

**Optional fields:**
- `license` -- SPDX license identifier
- `metadata` -- arbitrary key-value pairs

See the [full specification](https://agentskills.io/specification) for all
available fields.

### Tips for writing effective skills

- **Be specific.** Agents work best with concrete instructions, not vague
  guidelines. "Run `git log --oneline $(git describe --tags --abbrev=0)..HEAD`"
  is better than "check the git log."
- **Include when-to-use guidance.** Help the agent decide whether this skill
  applies to the current task.
- **Use scripts for complex logic.** If a skill involves multi-step shell
  operations, put them in `scripts/` rather than embedding long code blocks
  in the markdown.
- **Keep it focused.** One skill should do one thing well. Split broad topics
  into multiple skills.

## Creating a module flake

A module flake exports a skill with a tool dependency:

```nix
# module.nix
{ lib, ... }:
{
  options.perSystem = lib.mkPerSystemOption ({ lib, config, pkgs, ... }:
    let
      cfg = config.agentkit.skills.my-tool;
    in
    {
      options.agentkit.skills.my-tool = {
        package = lib.mkPackageOption pkgs "my-tool" { };
      };

      config.agentkit.skills.my-tool.enable = lib.mkDefault false;
      config.agentkit.skills.my-tool.path = lib.mkIf cfg.enable ./skill;
      config.agentkit.skills.my-tool.packages = lib.mkIf cfg.enable [
        cfg.package
      ];
    }
  );
}
```

```nix
# flake.nix
{
  description = "My agent skill module";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    agentkit.url = "github:ungood/agentkit";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      imports = [ inputs.agentkit.flakeModules.default ];

      flake.flakeModules.default = import ./module.nix;
    };
}
```

## Adding commands

Commands define reusable slash-command templates. They can be part of a module
or defined standalone:

```nix
agentkit.commands = {
  release = {
    description = "Prepare a release for this project";
    template = ''
      Prepare a release for this project. Check the git log since the last
      tag, categorize changes, and draft release notes.
      $ARGUMENTS
    '';
  };

  review = {
    description = "Review code changes";
    template = ''
      Review the current changes for correctness, style, and potential issues.
      $ARGUMENTS
    '';
    agent = "code-review";  # optional: specify which agent handles this
    model = "anthropic/claude-sonnet-4-5";  # optional: model override
  };
};
```

The `$ARGUMENTS` placeholder is replaced with whatever the user types after
the slash command (e.g., `/release v2.0` passes `v2.0` as arguments).

## Compatibility filtering

If a skill only works with specific agent runtimes, use the `compatibility`
option:

```nix
agentkit.skills.opencode-only = {
  path = ./skills/opencode-only;
  compatibility = [ "opencode" ];  # only deployed to OpenCode
};
```

An empty list (the default) means the skill is compatible with all runtimes.

## How consumers use your module

Consumers import your module and enable it:

```nix
{
  inputs = {
    agentkit.url = "github:ungood/agentkit";
    my-skill.url = "github:you/my-skill";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.agentkit.flakeModules.default
        inputs.my-skill.flakeModules.default
      ];

      perSystem = { config, pkgs, ... }: {
        agentkit = {
          enable = true;
          runtimes.opencode.enable = true;
          skills.my-tool.enable = true;
        };

        # Override the package if needed
        # agentkit.skills.my-tool.package = pkgs.my-tool-fork;

        devShells.default = pkgs.mkShell {
          inputsFrom = [ config.agentkit.devshell.shell ];
        };
      };
    };
}
```

## Options reference

All agentkit options are per-system (inside `perSystem`) so that `pkgs` is
available for package declarations.

### Core options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `agentkit.enable` | `bool` | `false` | Enable agentkit |
| `agentkit.skills.<name>.enable` | `bool` | `true` | Whether this skill is active (modules override to `false`) |
| `agentkit.skills.<name>.path` | `path?` | `null` | Path to Agent Skills-compliant directory |
| `agentkit.skills.<name>.packages` | `[package]` | `[]` | Tool dependencies (auto-added to devshell) |
| `agentkit.skills.<name>.compatibility` | `[str]` | `[]` | Restrict to specific runtimes (empty = all) |

### Runtime options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `agentkit.runtimes.opencode.enable` | `bool` | `false` | Enable the OpenCode runtime |

### Command options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `agentkit.commands.<name>.description` | `str` | -- | Short description for the command |
| `agentkit.commands.<name>.template` | `str` | -- | Command template (`$ARGUMENTS` for user input) |
| `agentkit.commands.<name>.agent` | `str?` | `null` | Optional agent to use |
| `agentkit.commands.<name>.model` | `str?` | `null` | Optional model override |

### Devshell options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `agentkit.devshell.packages` | `[package]` | `[]` | Extra packages (skill packages added automatically) |
| `agentkit.devshell.shell` | `package` | -- | Aggregated shell; use with `inputsFrom` |

## Testing your module

Verify your skill directories are valid:

```sh
nix flake check
```

agentkit's test suite validates that skill directories are copied correctly
and that command frontmatter is generated properly.
