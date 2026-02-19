# agentkit tests
#
# Runs as part of `nix flake check`. Tests verify that:
# 1. Skill directories are copied as-is (Agent Skills spec compliance)
# 2. Commands render correctly to command markdown format
{ lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      ocLib = import ../modules/harnesses/opencode/lib.nix { inherit lib; };

      # Test skill fixtures (Agent Skills-compliant directories)
      testSkillDir = ../tests/fixtures/test-skill;
      minimalSkillDir = ../tests/fixtures/minimal-skill;
      extrasSkillDir = ../tests/fixtures/skill-with-extras;

      # Build a config directory simulating what the harness does
      testConfigDir = pkgs.runCommand "test-config-dir" { } ''
        mkdir -p $out/skills
        cp -rL ${testSkillDir} $out/skills/test-skill
        cp -rL ${minimalSkillDir} $out/skills/minimal-skill
        cp -rL ${extrasSkillDir} $out/skills/skill-with-extras
      '';

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

      commandFile = pkgs.writeText "test-command.md" (ocLib.renderCommand testCommand);
      fullCommandFile = pkgs.writeText "full-command.md" (ocLib.renderCommand fullCommand);
    in
    {
      checks = {
        # Test that skill directories are copied with SKILL.md intact
        skill-directory-copy = pkgs.runCommand "agentkit-test-skill-directory" { } ''
          # Verify SKILL.md exists in copied directory
          test -f ${testConfigDir}/skills/test-skill/SKILL.md || (echo "FAIL: missing SKILL.md"; exit 1)

          # Verify frontmatter is preserved as-is (not regenerated)
          grep -q 'name: test-skill' ${testConfigDir}/skills/test-skill/SKILL.md || (echo "FAIL: missing name in frontmatter"; exit 1)
          grep -q 'description: A test skill for verification' ${testConfigDir}/skills/test-skill/SKILL.md || (echo "FAIL: missing description"; exit 1)
          grep -q 'license: MIT' ${testConfigDir}/skills/test-skill/SKILL.md || (echo "FAIL: missing license"; exit 1)
          grep -q 'audience: developers' ${testConfigDir}/skills/test-skill/SKILL.md || (echo "FAIL: missing metadata"; exit 1)

          # Verify body content is preserved
          grep -q '## What I do' ${testConfigDir}/skills/test-skill/SKILL.md || (echo "FAIL: missing content header"; exit 1)
          grep -q 'Test things' ${testConfigDir}/skills/test-skill/SKILL.md || (echo "FAIL: missing content body"; exit 1)

          echo "PASS: skill directory copy"
          mkdir -p $out && touch $out/passed
        '';

        # Test minimal skill directory
        minimal-skill-directory = pkgs.runCommand "agentkit-test-minimal-skill" { } ''
          test -f ${testConfigDir}/skills/minimal-skill/SKILL.md || (echo "FAIL: missing SKILL.md"; exit 1)
          grep -q 'name: minimal-skill' ${testConfigDir}/skills/minimal-skill/SKILL.md || (echo "FAIL: missing name"; exit 1)
          grep -q 'description: A minimal skill' ${testConfigDir}/skills/minimal-skill/SKILL.md || (echo "FAIL: missing description"; exit 1)

          # Verify body content
          grep -q 'Just do the thing.' ${testConfigDir}/skills/minimal-skill/SKILL.md || (echo "FAIL: missing body"; exit 1)

          echo "PASS: minimal skill directory"
          mkdir -p $out && touch $out/passed
        '';

        # Test skill with extra directories (scripts/, references/)
        skill-with-extras = pkgs.runCommand "agentkit-test-skill-extras" { } ''
          test -f ${testConfigDir}/skills/skill-with-extras/SKILL.md || (echo "FAIL: missing SKILL.md"; exit 1)
          test -f ${testConfigDir}/skills/skill-with-extras/scripts/process.sh || (echo "FAIL: missing script"; exit 1)
          test -f ${testConfigDir}/skills/skill-with-extras/references/REFERENCE.md || (echo "FAIL: missing reference"; exit 1)

          # Verify SKILL.md content
          grep -q 'name: skill-with-extras' ${testConfigDir}/skills/skill-with-extras/SKILL.md || (echo "FAIL: missing name"; exit 1)
          grep -q 'license: Apache-2.0' ${testConfigDir}/skills/skill-with-extras/SKILL.md || (echo "FAIL: missing license"; exit 1)

          # Verify script content is preserved
          grep -q 'Processing data' ${testConfigDir}/skills/skill-with-extras/scripts/process.sh || (echo "FAIL: script content wrong"; exit 1)

          # Verify reference content is preserved
          grep -q 'Reference Guide' ${testConfigDir}/skills/skill-with-extras/references/REFERENCE.md || (echo "FAIL: reference content wrong"; exit 1)

          echo "PASS: skill with extras"
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
