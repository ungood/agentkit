# agentkit OpenCode harness
#
# Converts framework-agnostic agentkit definitions into OpenCode-specific
# configuration. Registers itself into the agentkit harness system so the
# devshell aggregator can include its env vars.
#
# Provides:
#   - agentkit.opencode.enable              (top-level toggle)
#   - agentkit.opencode.generatedSkills     (rendered SKILL.md content)
#   - agentkit.opencode.generatedCommands   (rendered command.md content)
#   - perSystem.agentkit.opencode.devshell  (devshell integration)
{
  lib,
  config,
  ...
}:
let
  inherit (lib)
    filterAttrs
    mapAttrs
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.agentkit;
  ocCfg = cfg.opencode;
  ocLib = import ./lib.nix { inherit lib; };

  # Filter skills to those compatible with opencode (or unrestricted)
  compatibleSkills = filterAttrs (
    _: skill: skill.compatibility == [ ] || builtins.elem "opencode" skill.compatibility
  ) cfg.skills;

  generatedSkills = mapAttrs (_: ocLib.renderSkill) compatibleSkills;
  generatedCommands = mapAttrs (_: ocLib.renderCommand) cfg.commands;
in
{
  options.agentkit.opencode = {
    enable = mkEnableOption "OpenCode harness";

    generatedSkills = mkOption {
      type = types.attrsOf types.str;
      internal = true;
      readOnly = true;
      default = { };
      description = "Generated SKILL.md content for each skill, keyed by skill name.";
    };

    generatedCommands = mkOption {
      type = types.attrsOf types.str;
      internal = true;
      readOnly = true;
      default = { };
      description = "Generated command markdown content for each command, keyed by command name.";
    };
  };

  config = mkIf (cfg.enable && ocCfg.enable) {
    agentkit.opencode = {
      inherit generatedSkills generatedCommands;
    };
  };

  # perSystem: devshell integration + harness registration
  options.perSystem = lib.mkPerSystemOption (
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      psCfg = config.agentkit.opencode.devshell;

      # Individual skill and command files as store paths
      skillFiles = mapAttrs (
        name: content: pkgs.writeText "${name}-SKILL.md" content
      ) ocCfg.generatedSkills;

      commandFiles = mapAttrs (
        name: content: pkgs.writeText "${name}-command.md" content
      ) ocCfg.generatedCommands;

      # Build a store path with the directory structure OpenCode expects:
      #   skills/<name>/SKILL.md
      #   commands/<name>.md
      configDir = pkgs.runCommand "agentkit-opencode-config" { } (
        ''
          mkdir -p $out
        ''
        + lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: file: ''
            mkdir -p $out/skills/${name}
            cp ${file} $out/skills/${name}/SKILL.md
          '') skillFiles
        )
        + lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: file: ''
            mkdir -p $out/commands
            cp ${file} $out/commands/${name}.md
          '') commandFiles
        )
      );

      shellHook = ''
        export OPENCODE_CONFIG_DIR="${configDir}"
      '';
    in
    {
      options.agentkit.opencode.devshell = {
        enable = mkEnableOption "OpenCode devshell integration via OPENCODE_CONFIG_DIR";

        configDir = mkOption {
          type = types.package;
          readOnly = true;
          default = configDir;
          description = ''
            A derivation containing the OpenCode config directory structure.
            Contains skills/ and commands/ subdirectories with generated files.
          '';
        };

        shellHook = mkOption {
          type = types.str;
          readOnly = true;
          default = shellHook;
          description = "Shell hook that sets OPENCODE_CONFIG_DIR.";
        };

        shell = mkOption {
          type = types.package;
          readOnly = true;
          default = pkgs.mkShell {
            inherit shellHook;
          };
          description = ''
            A minimal shell with OPENCODE_CONFIG_DIR set. Use with `inputsFrom`
            in your devShell definition.
          '';
        };
      };

      # Register into the per-system harness devshell aggregator
      config.agentkit._harnessDevshells.opencode = mkIf (cfg.enable && ocCfg.enable) {
        inherit (psCfg) enable;
        inherit (psCfg) shellHook configDir;
      };
    }
  );
}
