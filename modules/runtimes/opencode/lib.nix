# agentkit OpenCode rendering library
#
# Pure functions that convert agentkit types into OpenCode file formats.
#
# Skills follow the Agent Skills specification and are copied as-is —
# no rendering is needed. Only commands require frontmatter generation.
{ lib }:
let
  inherit (lib) concatStringsSep;

  # Render a command's markdown frontmatter
  renderCommandFrontmatter =
    command:
    concatStringsSep "\n" (
      [ "---" ]
      ++ [ "description: ${command.description}" ]
      ++ (lib.optional (command.agent != null) "agent: ${command.agent}")
      ++ (lib.optional (command.model != null) "model: ${command.model}")
      ++ [ "---" ]
    );
in
{
  # Render a command definition to a complete command markdown string
  renderCommand = command: ''
    ${renderCommandFrontmatter command}

    ${command.template}'';
}
