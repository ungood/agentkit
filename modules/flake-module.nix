# agentkit flake-parts module
#
# Framework-agnostic core. Defines shared options for skills, commands, and
# a harness registry. Individual harnesses (opencode, claude-code, etc.) are
# separate modules that consume these definitions and register themselves.
#
# Skills follow the Agent Skills specification (https://agentskills.io/specification).
# Each skill is a directory containing a SKILL.md file with YAML frontmatter.
#
# Usage:
#   imports = [ inputs.agentkit.flakeModules.default ];
#
#   agentkit = {
#     enable = true;
#     opencode.enable = true;
#
#     skills.git-release = {
#       directory = ./skills/git-release;
#     };
#   };
#
#   perSystem = { config, ... }: {
#     agentkit.devshell.enable = true;  # aggregates all enabled harnesses
#     devShells.default = pkgs.mkShell {
#       inputsFrom = [ config.agentkit.devshell.shell ];
#     };
#   };
{
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    types
    ;

  agentkitTypes = import ../lib/types.nix { inherit lib; };
in
{
  imports = [
    ./harnesses/opencode
  ];

  options.agentkit = {
    enable = mkEnableOption "agentkit agent platform module system";

    skills = mkOption {
      type = types.attrsOf agentkitTypes.skill;
      default = { };
      description = ''
        Agent skills to export from this flake.

        Skills follow the Agent Skills specification. Each skill is a directory
        containing a SKILL.md file with YAML frontmatter. Agentkit copies these
        directories as-is into the framework's expected location — it does not
        parse or regenerate the frontmatter.

        Each enabled harness (opencode, claude-code, etc.) copies the skill
        directories into the framework's expected configuration path.
      '';
      example = {
        git-release = {
          directory = ./skills/git-release;
        };
      };
    };

    commands = mkOption {
      type = types.attrsOf agentkitTypes.command;
      default = { };
      description = ''
        Agent commands to export from this flake.

        Commands are reusable slash command templates. Each enabled harness
        converts them into the framework's expected format.
      '';
      example = {
        release = {
          description = "Prepare a release";
          template = "Prepare a release for this project. $ARGUMENTS";
        };
      };
    };
  };

  # Aggregate devshell from all enabled harnesses
  options.perSystem = lib.mkPerSystemOption (
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      devCfg = config.agentkit.devshell;

      # Collect shell hooks from all registered per-system harness devshells
      enabledHarnesses = lib.filterAttrs (_: h: h.enable) config.agentkit._harnessDevshells;

      aggregatedShellHook = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (_: h: h.shellHook) enabledHarnesses
      );
    in
    {
      options.agentkit = {
        devshell = {
          enable = mkEnableOption "agentkit devshell integration (aggregates all enabled harnesses)";

          shellHook = mkOption {
            type = types.str;
            readOnly = true;
            default = aggregatedShellHook;
            description = "Combined shell hook from all enabled harnesses.";
          };

          shell = mkOption {
            type = types.package;
            readOnly = true;
            default = pkgs.mkShell {
              inherit (devCfg) shellHook;
            };
            description = ''
              A minimal shell with all enabled harness env vars set.
              Use with `inputsFrom` in your devShell definition.
            '';
          };
        };

        # Internal: per-system harness devshell registry.
        # Each harness module registers itself here.
        _harnessDevshells = mkOption {
          type = types.attrsOf (
            types.submodule {
              options = {
                enable = mkOption {
                  type = types.bool;
                  default = false;
                };
                shellHook = mkOption {
                  type = types.str;
                  default = "";
                };
                configDir = mkOption {
                  type = types.nullOr types.package;
                  default = null;
                };
              };
            }
          );
          internal = true;
          default = { };
          description = "Per-system harness devshell configurations.";
        };
      };
    }
  );
}
