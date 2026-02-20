# agentkit OpenCode home-manager module
#
# A standalone home-manager module that can be imported into a home-manager
# configuration. Skills and commands are defined at the agentkit level
# (runtime-agnostic), and the OpenCode runtime consumes them — mirroring
# the flake-parts module structure.
#
# Skills follow the Agent Skills specification — each value is a path to a
# directory containing SKILL.md (and optional scripts/, references/, assets/).
#
# Usage in a home-manager config:
#   imports = [ inputs.agentkit.homeModules.opencode ];
#
#   agentkit = {
#     runtimes.opencode.enable = true;
#
#     skills = {
#       tldr = ./path/to/tldr/skill;
#       git-release = ./skills/git-release;
#     };
#
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
  cfg = config.agentkit;
  ocCfg = cfg.runtimes.opencode;
in
{
  options.agentkit = {
    runtimes.opencode = {
      enable = mkEnableOption "agentkit OpenCode integration";
    };

    skills = mkOption {
      type = types.attrsOf types.path;
      default = { };
      description = ''
        Skill directories, keyed by skill name.
        Each value is a path to an Agent Skills-compliant directory containing
        SKILL.md. These are passed to all enabled runtimes.
      '';
    };

    commands = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = ''
        Pre-rendered command content, keyed by command name.
        Each value is the full command markdown content (including frontmatter).
        These are passed to all enabled runtimes.
      '';
    };
  };

  config = mkIf ocCfg.enable {
    programs.opencode = {
      inherit (cfg) skills commands;
    };
  };
}
