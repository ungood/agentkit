# agentkit type definitions
#
# Framework-agnostic types for agent platform extension points.
# These are consumed by backend modules (opencode, etc.) to generate
# framework-specific configuration.
{ lib }:
let
  inherit (lib) mkOption types;
in
{
  # A skill definition: reusable instructions that an agent can load on demand.
  #
  # Skills are framework-agnostic at this layer. Backend modules (e.g., opencode)
  # convert them into the framework's expected format (e.g., SKILL.md with YAML frontmatter).
  skill = types.submodule (
    { name, ... }:
    {
      options = {
        name = mkOption {
          type = types.str;
          default = name;
          description = ''
            The skill name. Must be lowercase alphanumeric with single hyphen
            separators (e.g., "git-release"). Defaults to the attribute name.
          '';
        };

        description = mkOption {
          type = types.str;
          description = ''
            A short description of what this skill does and when to use it.
            Used by agents to decide whether to load the skill.
          '';
        };

        content = mkOption {
          type = types.lines;
          description = ''
            The skill's instruction content (markdown). This is the body of the
            skill that the agent receives when it loads the skill.
          '';
        };

        license = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Optional SPDX license identifier.";
        };

        compatibility = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            List of frameworks this skill is compatible with (e.g., ["opencode"]).
            Empty means compatible with all frameworks.
          '';
          example = [
            "opencode"
            "claude-code"
          ];
        };

        metadata = mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = "Arbitrary string-to-string metadata map.";
          example = {
            audience = "maintainers";
            workflow = "github";
          };
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
