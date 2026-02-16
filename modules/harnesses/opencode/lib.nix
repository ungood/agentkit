# agentkit OpenCode rendering library
#
# Pure functions that convert agentkit types into OpenCode file formats.
{ lib }:
let
  inherit (lib)
    concatStringsSep
    mapAttrsToList
    ;

  # Render YAML frontmatter for a SKILL.md file
  renderFrontmatter =
    skill:
    let
      metadataLines = mapAttrsToList (k: v: "  ${k}: ${v}") skill.metadata;
    in
    concatStringsSep "\n" (
      [ "---" ]
      ++ [ "name: ${skill.name}" ]
      ++ [ "description: ${skill.description}" ]
      ++ (lib.optional (skill.license != null) "license: ${skill.license}")
      ++ (lib.optional (
        skill.compatibility != [ ]
      ) "compatibility: ${concatStringsSep ", " skill.compatibility}")
      ++ (lib.optionals (skill.metadata != { }) ([ "metadata:" ] ++ metadataLines))
      ++ [ "---" ]
    );

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
  # Render a skill definition to a complete SKILL.md string
  renderSkill = skill: ''
    ${renderFrontmatter skill}

    ${skill.content}'';

  # Render a command definition to a complete command markdown string
  renderCommand = command: ''
    ${renderCommandFrontmatter command}

    ${command.template}'';
}
