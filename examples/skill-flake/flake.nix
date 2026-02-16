# Example: A flake that exports agent skills and commands
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

      # Enable agentkit (harnesses are not needed for a library that just exports skills)
      agentkit.enable = true;

      # Define skills that this flake exports
      agentkit.skills = {
        git-release = {
          description = "Create consistent releases and changelogs";
          license = "MIT";
          metadata = {
            audience = "maintainers";
            workflow = "github";
          };
          content = ''
            ## What I do
            - Draft release notes from merged PRs
            - Propose a version bump based on conventional commits
            - Provide a copy-pasteable `gh release create` command

            ## When to use me
            Use this when you are preparing a tagged release.
            Ask clarifying questions if the target versioning scheme is unclear.

            ## Steps
            1. Run `git log --oneline $(git describe --tags --abbrev=0)..HEAD`
            2. Categorize changes into Added, Changed, Fixed, Removed
            3. Determine version bump (major/minor/patch) from commit prefixes
            4. Draft the release notes in Keep a Changelog format
            5. Provide the `gh release create` command
          '';
        };

        nix-module = {
          description = "Write idiomatic NixOS/home-manager modules";
          license = "MIT";
          content = ''
            ## What I do
            Help write well-structured Nix modules following community conventions.

            ## Guidelines
            - Use `mkEnableOption` for feature flags
            - Use `mkOption` with proper types from `lib.types`
            - Guard config with `mkIf cfg.enable`
            - Use `lib.mkDefault` for overridable defaults
            - Prefer `lib.optional` / `lib.optionals` over if-then-else
            - Namespace options appropriately (e.g., `services.myApp`, `programs.myTool`)
            - Add descriptions to all options
            - Use `literalExpression` for complex examples
          '';
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
