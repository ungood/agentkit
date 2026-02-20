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
#   - perSystem.agentkit.runtimes.opencode.enable      (runtime toggle)
#   - perSystem.agentkit.runtimes.opencode.devshell.*   (devshell integration)
{ lib, ... }:
let
  inherit (lib)
    filterAttrs
    mapAttrs
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  ocLib = import ./lib.nix { inherit lib; };
in
{
  options.perSystem = lib.mkPerSystemOption (
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.agentkit;
      ocCfg = cfg.runtimes.opencode;

      # Filter skills: must be enabled, have a path, and be compatible with opencode
      compatibleSkills = filterAttrs (
        _: skill:
        skill.enable
        && skill.path != null
        && (skill.compatibility == [ ] || builtins.elem "opencode" skill.compatibility)
      ) cfg.skills;

      # Resolve skill directories (paths to Agent Skills-compliant directories)
      skillDirs = mapAttrs (_: skill: skill.path) compatibleSkills;

      # Render commands to markdown with frontmatter
      generatedCommands = mapAttrs (_: ocLib.renderCommand) cfg.commands;

      commandFiles = mapAttrs (
        name: content: pkgs.writeText "${name}-command.md" content
      ) generatedCommands;

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
          '') skillDirs
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
      options.agentkit.runtimes.opencode = {
        enable = mkEnableOption "OpenCode agent runtime";

        devshell = {
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
      };

      # Auto-register into the per-system runtime devshell aggregator
      # when the runtime is enabled
      config.agentkit._runtimeDevshells.opencode = mkIf (cfg.enable && ocCfg.enable) {
        enable = true;
        inherit shellHook configDir;
      };
    }
  );
}
