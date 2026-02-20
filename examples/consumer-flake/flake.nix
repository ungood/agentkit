# Example: A project flake that consumes skills via devshell
#
# Skills follow the Agent Skills specification (https://agentskills.io/specification).
# Each skill is a directory containing a SKILL.md file.
#
# This shows how a project would use agentkit to inject skills into
# its development environment via OPENCODE_CONFIG_DIR.
{
  description = "Example project consuming agentkit skills";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    # In a real flake:
    # agentkit.url = "github:ungood/agentkit";
    # my-skills.url = "github:someone/my-skills";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      imports = [
        # Import agentkit
        # In a real flake: inputs.agentkit.flakeModules.default
        ../../modules/flake-module.nix

        # Import skills from another flake
        # In a real flake: inputs.my-skills.flakeModules.default
        # (skills merge automatically via the module system)
      ];

      # Enable agentkit and the OpenCode runtime
      agentkit = {
        enable = true;
        runtimes.opencode.enable = true;
      };

      # You can also define project-local skills (pointing to local directories)
      agentkit.skills.project-conventions = {
        directory = ./skills/project-conventions;
      };

      agentkit.commands.test = {
        description = "Run the project test suite";
        template = ''
          Run the full test suite for this project.
          If specific tests are mentioned, focus on those.
          Show failures clearly and suggest fixes.
          $ARGUMENTS
        '';
      };

      # Enable devshell integration (aggregated across all agent runtimes)
      perSystem =
        { config, pkgs, ... }:
        {
          # Enable devshell for individual runtimes...
          agentkit.runtimes.opencode.devshell.enable = true;

          # ...then use the aggregated shell that merges all runtime hooks
          agentkit.devshell.enable = true;

          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              opencode
            ];

            # This sets OPENCODE_CONFIG_DIR (and any other runtime env vars)
            inputsFrom = [ config.agentkit.devshell.shell ];
          };
        };
    };
}
