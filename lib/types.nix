# agentkit type definitions
#
# Framework-agnostic types for agent platform extension points.
# These are consumed by agent runtime modules (opencode, etc.) to generate
# runtime-specific configuration.
#
# Skills follow the Agent Skills specification (https://agentskills.io/specification).
# Each skill is a directory containing at minimum a SKILL.md file with YAML
# frontmatter. Agentkit does not parse or rebuild the frontmatter — it treats
# the directory as an opaque unit conforming to the spec.
{ lib }:
let
  inherit (lib) mkOption types;
in
{
  # A skill definition: a directory following the Agent Skills specification.
  #
  # The directory must contain a SKILL.md file with valid YAML frontmatter
  # (name, description, etc.) and may optionally include scripts/, references/,
  # and assets/ subdirectories. See https://agentskills.io/specification.
  #
  # Agentkit simply copies the directory into the agent runtime's expected
  # location. It does not parse or regenerate the SKILL.md frontmatter.
  #
  # Skill modules (like tldr) set `enable = mkDefault false` so they are
  # opt-in. Manually defined skills default to enabled.
  skill = types.submodule (
    { name, ... }:
    {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Whether this skill is enabled. Defaults to true for manually
            defined skills. Skill modules override this to false so they
            are opt-in.
          '';
        };

        name = mkOption {
          type = types.str;
          default = name;
          description = ''
            The skill name. Must match the `name` field in SKILL.md frontmatter
            and follow Agent Skills naming rules: lowercase alphanumeric with
            single hyphen separators (e.g., "git-release"). Defaults to the
            attribute name.
          '';
        };

        path = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = ''
            Path to the skill directory. Must contain a SKILL.md file conforming
            to the Agent Skills specification (https://agentskills.io/specification).

            The directory may also include optional subdirectories such as
            scripts/, references/, and assets/.

            Skill modules set this automatically when enabled. Set it manually
            for inline skill definitions.
          '';
        };

        packages = mkOption {
          type = types.listOf types.package;
          default = [ ];
          description = ''
            Packages (tool dependencies) this skill requires. These are
            automatically added to the devshell when the skill is enabled.

            For example, a skill that teaches agents to use `jq` would set
            `packages = [ pkgs.jq ]` so the tool is available in the shell.

            Skill modules typically set this via their configurable `package`
            option. Inline skills set it directly.
          '';
        };

        compatibility = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            List of agent runtimes this skill is compatible with (e.g., ["opencode"]).
            Empty means compatible with all runtimes.

            This is an agentkit-specific field for filtering skills by runtime —
            it is not part of the Agent Skills specification.
          '';
          example = [
            "opencode"
            "claude-code"
          ];
        };
      };
    }
  );

  # A command definition: a reusable slash command template.
  command = types.submodule (
    { name, ... }:
    {
      options = {
        name = mkOption {
          type = types.str;
          default = name;
          description = ''
            The command name. Used as the slash command identifier (e.g., "release"
            becomes /release). Defaults to the attribute name.
          '';
        };

        description = mkOption {
          type = types.str;
          description = "A short description of what this command does.";
        };

        template = mkOption {
          type = types.lines;
          description = ''
            The command template content (markdown). Use $ARGUMENTS for
            user-provided arguments.
          '';
        };

        agent = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Optional agent to use when running this command.";
        };

        model = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Optional model override for this command.";
        };
      };
    }
  );
}
