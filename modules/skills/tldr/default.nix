# agentkit skill module: tldr
#
# Teaches agents to look up unfamiliar CLI tools using tldr pages.
# Installs tealdeer (a fast tldr client) as a dependency.
#
# This module follows the same pattern as home-manager program modules:
#   - agentkit.skills.tldr.enable   — opt-in toggle (flake-level)
#   - perSystem.agentkit.skills.tldr.package — configurable package
#
# When enabled, the module:
#   1. Registers the skill directory (flake-level)
#   2. Adds the package to agentkit.devshell.packages (per-system)
#
# Usage:
#   imports = [ inputs.agentkit.flakeModules.tldr ];
#   agentkit.skills.tldr.enable = true;
{
  lib,
  config,
  ...
}:
let
  cfg = config.agentkit.skills.tldr;
in
{
  # Opt-in: skill modules default to disabled.
  # The skill type's `enable` defaults to true (for manual skills), so we
  # override it here with mkDefault false to make this module opt-in.
  config.agentkit.skills.tldr.enable = lib.mkDefault false;

  # When enabled, set the skill directory
  config.agentkit.skills.tldr.directory = lib.mkIf cfg.enable ./skill;

  # Per-system: package option and devshell contribution
  options.perSystem = lib.mkPerSystemOption (
    {
      lib,
      config,
      pkgs,
      ...
    }:
    {
      options.agentkit.skills.tldr = {
        package = lib.mkPackageOption pkgs "tealdeer" { };
      };

      # When enabled, contribute the package to the aggregated devshell
      config.agentkit.devshell.packages = lib.mkIf cfg.enable [
        config.agentkit.skills.tldr.package
      ];
    }
  );
}
