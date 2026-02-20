# agentkit OpenCode home-manager module
#
# A standalone home-manager module that can be imported into a home-manager
# configuration. Uses the same skill type as the flake-parts module so that
# skills can declare their own packages.
#
# Skills follow the Agent Skills specification — each skill has a `path`
# to a directory containing SKILL.md, and optional `packages` for tool
# dependencies.
#
# Usage in a home-manager config:
#   imports = [ inputs.agentkit.homeModules.default ];
#
#   agentkit = {
#     runtimes.opencode.enable = true;
#
#     skills = {
#       tldr.enable = true;
#       my-skill = {
#         path = ./skills/my-skill;
#         packages = [ pkgs.my-tool ];
#       };
#     };
#   };
{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    concatLists
    filterAttrs
    mapAttrs
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  agentkitTypes = import ../../../lib/types.nix { inherit lib; };
  ocLib = import ./lib.nix { inherit lib; };

  cfg = config.agentkit;
  ocCfg = cfg.runtimes.opencode;

  # Filter skills: must be enabled, have a path, and be compatible with opencode
  compatibleSkills = filterAttrs (
    _: skill:
    skill.enable
    && skill.path != null
    && (skill.compatibility == [ ] || builtins.elem "opencode" skill.compatibility)
  ) cfg.skills;

  # Resolve skill directories
  skillDirs = mapAttrs (_: skill: skill.path) compatibleSkills;

  # Render commands to markdown with frontmatter
  generatedCommands = mapAttrs (_: ocLib.renderCommand) cfg.commands;

  # Aggregate packages from all enabled skills
  skillPackages = concatLists (
    mapAttrsToList (_: skill: if skill.enable then skill.packages else [ ]) cfg.skills
  );
in
{
  options.agentkit = {
    runtimes.opencode = {
      enable = mkEnableOption "agentkit OpenCode integration";
    };

    skills = mkOption {
      type = types.attrsOf agentkitTypes.skill;
      default = { };
      description = ''
        Agent skills, keyed by skill name.
        Each skill has a path to an Agent Skills-compliant directory and
        optional packages for tool dependencies. These are passed to all
        enabled runtimes.
      '';
    };

    commands = mkOption {
      type = types.attrsOf agentkitTypes.command;
      default = { };
      description = ''
        Agent commands.
        Commands are reusable slash command templates. Each enabled agent
        runtime converts them into its expected format.
      '';
    };
  };

  config = mkIf ocCfg.enable {
    home.packages = skillPackages;

    programs.opencode = {
      skills = skillDirs;
      commands = generatedCommands;
    };
  };
}
