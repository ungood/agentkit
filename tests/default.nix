# agentkit tests
#
# Runs as part of `nix flake check`. Tests verify that:
# 1. Skills render correctly to SKILL.md format
# 2. Commands render correctly to command markdown format
{ lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      ocLib = import ../modules/harnesses/opencode/lib.nix { inherit lib; };

      # Test skill definition
      testSkill = {
        name = "test-skill";
        description = "A test skill for verification";
        content = ''
          ## What I do
          - Test things
          - Verify correctness
        '';
        license = "MIT";
        compatibility = [ "opencode" ];
        metadata = {
          audience = "developers";
          category = "testing";
        };
      };

      # Test skill with minimal fields
      minimalSkill = {
        name = "minimal";
        description = "A minimal skill";
        content = "Just do the thing.";
        license = null;
        compatibility = [ ];
        metadata = { };
      };

      # Test command definition
      testCommand = {
        name = "test-cmd";
        description = "A test command";
        template = "Run the tests for this project. Focus on \$ARGUMENTS";
        agent = "build";
        model = null;
      };

      # Test command with all fields
      fullCommand = {
        name = "deploy";
        description = "Deploy the application";
        template = "Deploy to \$ARGUMENTS environment.";
        agent = "build";
        model = "anthropic/claude-sonnet-4-5";
      };

      # Write rendered content to files to avoid shell interpolation issues
      skillFile = pkgs.writeText "test-skill.md" (ocLib.renderSkill testSkill);
      minimalFile = pkgs.writeText "minimal-skill.md" (ocLib.renderSkill minimalSkill);
      commandFile = pkgs.writeText "test-command.md" (ocLib.renderCommand testCommand);
      fullCommandFile = pkgs.writeText "full-command.md" (ocLib.renderCommand fullCommand);
    in
    {
      checks = {
        # Test that skill rendering produces valid SKILL.md content
        skill-rendering = pkgs.runCommand "agentkit-test-skill-rendering" { } ''
          # Verify frontmatter markers
          head -1 ${skillFile} | grep -q '^---$' || (echo "FAIL: missing opening frontmatter"; exit 1)
          grep -q 'name: test-skill' ${skillFile} || (echo "FAIL: missing name"; exit 1)
          grep -q 'description: A test skill for verification' ${skillFile} || (echo "FAIL: missing description"; exit 1)
          grep -q 'license: MIT' ${skillFile} || (echo "FAIL: missing license"; exit 1)
          grep -q 'compatibility: opencode' ${skillFile} || (echo "FAIL: missing compatibility"; exit 1)
          grep -q 'metadata:' ${skillFile} || (echo "FAIL: missing metadata header"; exit 1)
          grep -q 'audience: developers' ${skillFile} || (echo "FAIL: missing metadata entry"; exit 1)

          # Verify content is present
          grep -q '## What I do' ${skillFile} || (echo "FAIL: missing content header"; exit 1)
          grep -q 'Test things' ${skillFile} || (echo "FAIL: missing content body"; exit 1)

          echo "PASS: skill rendering"
          mkdir -p $out && touch $out/passed
        '';

        # Test minimal skill rendering (no optional fields)
        minimal-skill-rendering = pkgs.runCommand "agentkit-test-minimal-skill" { } ''
          grep -q 'name: minimal' ${minimalFile} || (echo "FAIL: missing name"; exit 1)
          grep -q 'description: A minimal skill' ${minimalFile} || (echo "FAIL: missing description"; exit 1)

          # Should NOT contain optional fields
          ! grep -q 'license:' ${minimalFile} || (echo "FAIL: should not have license"; exit 1)
          ! grep -q 'compatibility:' ${minimalFile} || (echo "FAIL: should not have compatibility"; exit 1)
          ! grep -q 'metadata:' ${minimalFile} || (echo "FAIL: should not have metadata"; exit 1)

          echo "PASS: minimal skill rendering"
          mkdir -p $out && touch $out/passed
        '';

        # Test command rendering
        command-rendering = pkgs.runCommand "agentkit-test-command-rendering" { } ''
          head -1 ${commandFile} | grep -q '^---$' || (echo "FAIL: missing opening frontmatter"; exit 1)
          grep -q 'description: A test command' ${commandFile} || (echo "FAIL: missing description"; exit 1)
          grep -q 'agent: build' ${commandFile} || (echo "FAIL: missing agent"; exit 1)

          # model is null, should not appear
          ! grep -q 'model:' ${commandFile} || (echo "FAIL: should not have model"; exit 1)

          # Verify template content
          grep -q 'Run the tests' ${commandFile} || (echo "FAIL: missing template content"; exit 1)
          grep -q 'ARGUMENTS' ${commandFile} || (echo "FAIL: missing ARGUMENTS placeholder"; exit 1)

          echo "PASS: command rendering"
          mkdir -p $out && touch $out/passed
        '';

        # Test full command rendering (all fields)
        full-command-rendering = pkgs.runCommand "agentkit-test-full-command" { } ''
          grep -q 'description: Deploy the application' ${fullCommandFile} || (echo "FAIL: missing description"; exit 1)
          grep -q 'agent: build' ${fullCommandFile} || (echo "FAIL: missing agent"; exit 1)
          grep -q 'model: anthropic/claude-sonnet-4-5' ${fullCommandFile} || (echo "FAIL: missing model"; exit 1)

          echo "PASS: full command rendering"
          mkdir -p $out && touch $out/passed
        '';
      };
    };
}
