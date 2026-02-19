# agentkit OpenCode home-manager module
#
# A standalone home-manager module that can be imported into a home-manager
# configuration. It provides an `agentkit.opencode` option that accepts
# skill directories and commands and feeds them into the upstream
# `programs.opencode` module.
#
# Skills follow the Agent Skills specification — each value is a path to a
# directory containing SKILL.md (and optional scripts/, references/, assets/).
#
# Usage in a home-manager config:
#   imports = [ inputs.agentkit.homeModules.opencode ];
#
#   agentkit.opencode = {
#     skills = {
#       git-release = ./skills/git-release;
#     };
#     commands = {
#       release = "---\ndescription: ...\n...";
#     };
#   };
#
# Or, more commonly, the flake-parts module auto-generates these values and
# you pass them through via specialArgs or module arguments.
{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.agentkit.opencode;
in
{
  options.agentkit.opencode = {
    enable = mkEnableOption "agentkit OpenCode integration";

    skills = mkOption {
      type = types.attrsOf types.path;
      default = { };
      description = ''
        Skill directories, keyed by skill name.
        Each value is a path to an Agent Skills-compliant directory containing
        SKILL.md. These are merged into programs.opencode.skills.
      '';
    };

    commands = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = ''
        Pre-rendered command content, keyed by command name.
        Each value is the full command markdown content (including frontmatter).
        These are merged into programs.opencode.commands.
      '';
    };
  };

  config = mkIf cfg.enable {
    programs.opencode = {
      inherit (cfg) skills;
      inherit (cfg) commands;
    };
  };
}
