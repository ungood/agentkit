# agentkit OpenCode runtime adapter
#
# Converts framework-agnostic agentkit definitions into OpenCode-specific
# configuration. Registers itself into the agentkit runtime system so the
# devshell aggregator can include its env vars.
#
# Skills follow the Agent Skills specification and are copied as directories.
# Commands are rendered to markdown with frontmatter.
#
# Provides:
#   - agentkit.runtimes.opencode.enable              (top-level toggle)
#   - agentkit.runtimes.opencode.skillDirs           (skill directory paths)
#   - agentkit.runtimes.opencode.generatedCommands   (rendered command.md content)
#   - perSystem.agentkit.runtimes.opencode.devshell  (devshell integration)
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
  ocCfg = cfg.runtimes.opencode;
  ocLib = import ./lib.nix { inherit lib; };

  # Filter skills: must be enabled, have a directory, and be compatible with opencode
  compatibleSkills = filterAttrs (
    _: skill:
    skill.enable
    && skill.directory != null
    && (skill.compatibility == [ ] || builtins.elem "opencode" skill.compatibility)
  ) cfg.skills;

  # Resolve skill directories (paths to Agent Skills-compliant directories)
  skillDirs = mapAttrs (_: skill: skill.directory) compatibleSkills;

  generatedCommands = mapAttrs (_: ocLib.renderCommand) cfg.commands;
in
{
  options.agentkit.runtimes.opencode = {
    enable = mkEnableOption "OpenCode agent runtime";

    skillDirs = mkOption {
      type = types.attrsOf types.path;
      internal = true;
      readOnly = true;
      default = { };
      description = ''
        Skill directory paths for each compatible skill, keyed by skill name.
        Each path points to an Agent Skills-compliant directory containing SKILL.md.
      '';
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
    agentkit.runtimes.opencode = {
      inherit skillDirs generatedCommands;
    };
  };

  # perSystem: devshell integration + runtime registration
  options.perSystem = lib.mkPerSystemOption (
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      psCfg = config.agentkit.runtimes.opencode.devshell;

      commandFiles = mapAttrs (
        name: content: pkgs.writeText "${name}-command.md" content
      ) ocCfg.generatedCommands;

      # Build a store path with the directory structure OpenCode expects:
      #   skills/<name>/   (copied from Agent Skills directory)
      #   commands/<name>.md
      configDir = pkgs.runCommand "agentkit-opencode-config" { } (
        ''
          mkdir -p $out
        ''
        + lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: dir: ''
            mkdir -p $out/skills
            cp -rL ${dir} $out/skills/${name}
          '') ocCfg.skillDirs
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
      options.agentkit.runtimes.opencode.devshell = {
        enable = mkEnableOption "OpenCode devshell integration via OPENCODE_CONFIG_DIR";

        configDir = mkOption {
          type = types.package;
          readOnly = true;
          default = configDir;
          description = ''
            A derivation containing the OpenCode config directory structure.
            Contains skills/ and commands/ subdirectories.
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

      # Register into the per-system runtime devshell aggregator
      config.agentkit._runtimeDevshells.opencode = mkIf (cfg.enable && ocCfg.enable) {
        inherit (psCfg) enable;
        inherit (psCfg) shellHook configDir;
      };
    }
  );
}
