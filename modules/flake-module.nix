# agentkit flake-parts module
#
# Framework-agnostic core. Defines shared options for skills, commands, and
# a runtime registry. Individual agent runtimes (opencode, claude-code, etc.)
# are separate modules that consume these definitions and register themselves.
#
# Skills follow the Agent Skills specification (https://agentskills.io/specification).
# Each skill is a directory containing a SKILL.md file with YAML frontmatter.
#
# Usage:
#   imports = [ inputs.agentkit.flakeModules.default ];
#
#   agentkit = {
#     enable = true;
#     runtimes.opencode.enable = true;
#     skills.tldr.enable = true;
#   };
#
#   perSystem = { config, ... }: {
#     agentkit.devshell.enable = true;
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
    ./runtimes/opencode
  ];

  options.agentkit = {
    enable = mkEnableOption "agentkit agent platform module system";

    skills = mkOption {
      type = types.attrsOf agentkitTypes.skill;
      default = { };
      description = ''
        Agent skills registry.

        Skills follow the Agent Skills specification. Each skill is a directory
        containing a SKILL.md file with YAML frontmatter. Agentkit copies these
        directories as-is into the agent runtime's expected location — it does
        not parse or regenerate the frontmatter.

        Skill modules (like tldr) define their options here and set the
        directory automatically when enabled. You can also define skills
        manually by setting `directory` directly.
      '';
      example = {
        my-skill = {
          directory = ./skills/my-skill;
        };
      };
    };

    commands = mkOption {
      type = types.attrsOf agentkitTypes.command;
      default = { };
      description = ''
        Agent commands to export from this flake.

        Commands are reusable slash command templates. Each enabled agent
        runtime converts them into its expected format.
      '';
      example = {
        release = {
          description = "Prepare a release";
          template = "Prepare a release for this project. $ARGUMENTS";
        };
      };
    };
  };

  # Aggregate devshell from all enabled agent runtimes
  options.perSystem = lib.mkPerSystemOption (
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      devCfg = config.agentkit.devshell;

      # Collect shell hooks from all registered per-system runtime devshells
      enabledRuntimes = lib.filterAttrs (_: r: r.enable) config.agentkit._runtimeDevshells;

      aggregatedShellHook = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (_: r: r.shellHook) enabledRuntimes
      );
    in
    {
      options.agentkit = {
        devshell = {
          enable = mkEnableOption "agentkit devshell integration (aggregates all enabled agent runtimes)";

          packages = mkOption {
            type = types.listOf types.package;
            default = [ ];
            description = ''
              Packages to include in the aggregated devshell. Skill modules
              contribute their tool packages here (similar to home.packages
              in home-manager).
            '';
          };

          shellHook = mkOption {
            type = types.str;
            readOnly = true;
            default = aggregatedShellHook;
            description = "Combined shell hook from all enabled agent runtimes.";
          };

          shell = mkOption {
            type = types.package;
            readOnly = true;
            default = pkgs.mkShell {
              inherit (devCfg) shellHook packages;
            };
            description = ''
              A minimal shell with all enabled agent runtime env vars and skill
              packages. Use with `inputsFrom` in your devShell definition.
            '';
          };
        };

        # Internal: per-system runtime devshell registry.
        # Each agent runtime module registers itself here.
        _runtimeDevshells = mkOption {
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
          description = "Per-system agent runtime devshell configurations.";
        };
      };
    }
  );
}
