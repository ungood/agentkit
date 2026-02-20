# agentkit skill module: tldr
#
# Teaches agents to look up unfamiliar CLI tools using tldr pages.
# Installs tealdeer (a fast tldr client) as a dependency.
#
# This module follows the same pattern as home-manager program modules:
#   - agentkit.skills.tldr.enable  — opt-in toggle
#   - agentkit.skills.tldr.package — configurable package
#
# When enabled, the module sets the skill path and adds tealdeer
# to the skill's packages (auto-aggregated into the devshell).
#
# Usage:
#   agentkit.skills.tldr.enable = true;
{ lib, ... }:
{
  options.perSystem = lib.mkPerSystemOption (
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.agentkit.skills.tldr;
    in
    {
      options.agentkit.skills.tldr = {
        package = lib.mkPackageOption pkgs "tealdeer" { };
      };

      # Opt-in: skill modules default to disabled.
      # The skill type's `enable` defaults to true (for manual skills), so we
      # override it here with mkDefault false to make this module opt-in.
      config.agentkit.skills.tldr.enable = lib.mkDefault false;

      # When enabled, set the skill path and packages
      config.agentkit.skills.tldr.path = lib.mkIf cfg.enable ./skill;
      config.agentkit.skills.tldr.packages = lib.mkIf cfg.enable [
        cfg.package
      ];
    }
  );
}
