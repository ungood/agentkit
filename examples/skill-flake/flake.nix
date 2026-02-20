# Example: A flake that exports agent skills and commands
#
# Skills follow the Agent Skills specification (https://agentskills.io/specification).
# Each skill is a directory containing a SKILL.md file with YAML frontmatter.
#
# Other flakes can import this flake's module to gain these skills.
#
# Usage by consumers:
#   inputs.my-skills.url = "github:someone/my-skills";
#   imports = [ inputs.my-skills.flakeModules.default ];
{
  description = "Example agentkit skill library";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    # In a real flake, this would be:
    # agentkit.url = "github:ungood/agentkit";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      # Import the agentkit module
      # In a real flake: imports = [ inputs.agentkit.flakeModules.default ];
      imports = [ ../../modules/flake-module.nix ];

      # Enable agentkit (runtimes are not needed for a library that just exports skills)
      agentkit.enable = true;

      # Define skills that this flake exports.
      # Each skill points to an Agent Skills-compliant directory.
      agentkit.skills = {
        git-release = {
          directory = ./skills/git-release;
        };

        nix-module = {
          directory = ./skills/nix-module;
        };
      };

      agentkit.commands = {
        release = {
          description = "Prepare a release for this project";
          template = ''
            Prepare a release for this project. Check the git log since the last
            tag, categorize changes, and draft release notes.

            If a version is specified, use it. Otherwise, determine the appropriate
            version bump from conventional commit prefixes.

            $ARGUMENTS
          '';
          agent = "build";
        };
      };
    };
}
