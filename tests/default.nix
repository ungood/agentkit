# agentkit test suite
#
# Runs as part of `nix flake check`.
#
# Tests are organised as a matrix:
#   runtime  × target        × part
#   opencode   devshell        skills
#              home-manager    commands
#
# Naming convention:  <runtime>-<target>-<part>[-<detail>]
#
# Shared / pure-function unit tests (e.g. command rendering) live under
# the "lib-*" prefix.
{ lib, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      # ── shared helpers ────────────────────────────────────────────────
      ocLib = import ../modules/runtimes/opencode/lib.nix { inherit lib; };

      # Test fixtures (Agent Skills-compliant directories)
      fixtures = {
        test-skill = ../tests/fixtures/test-skill;
        minimal-skill = ../tests/fixtures/minimal-skill;
        skill-with-extras = ../tests/fixtures/skill-with-extras;
      };

      # Test command definitions
      testCommand = {
        name = "test-cmd";
        description = "A test command";
        template = "Run the tests for this project. Focus on \$ARGUMENTS";
        agent = "build";
        model = null;
      };

      fullCommand = {
        name = "deploy";
        description = "Deploy the application";
        template = "Deploy to \$ARGUMENTS environment.";
        agent = "build";
        model = "anthropic/claude-sonnet-4-5";
      };

      # Small shell-script assertion helper shared by all checks.
      # Usage:  ${assertFileExists "/path/to/file" "label"}
      assertFileExists =
        path: label: ''test -f ${path} || { echo "FAIL: ${label} – missing ${path}"; exit 1; }'';

      assertFileContains =
        path: pattern: label:
        ''grep -q '${pattern}' ${path} || { echo "FAIL: ${label} – pattern '${pattern}' not found in ${path}"; exit 1; }'';

      assertFileNotContains =
        path: pattern: label:
        ''! grep -q '${pattern}' ${path} || { echo "FAIL: ${label} – pattern '${pattern}' should not appear in ${path}"; exit 1; }'';

      assertDirExists =
        path: label: ''test -d ${path} || { echo "FAIL: ${label} – missing directory ${path}"; exit 1; }'';

      pass = name: ''
        echo "PASS: ${name}"
        mkdir -p $out && touch $out/passed
      '';

      # ── devshell target: evaluate the flake-parts module ──────────────
      #
      # We evaluate the actual flake-parts module with a test configuration
      # and inspect the resulting configDir derivation that the runtime
      # adapter produces. This is a true integration test.
      evalDevshell =
        {
          skills ? { },
          commands ? { },
        }:
        let
          eval = lib.evalModules {
            modules = [
              # Provide the perSystem "interface" expected by the modules.
              # We fake the minimal flake-parts perSystem plumbing.
              (_: {
                options.perSystem = lib.mkOption {
                  type = lib.types.functionTo (lib.types.submoduleWith { modules = perSystemModules; });
                  default = _: { };
                };
              })
            ];
          };

          perSystemModules = [
            # Core agentkit module (inlined; needs the option definitions)
            (
              { lib, config, ... }:
              let
                agentkitTypes = import ../lib/types.nix { inherit lib; };
                cfg = config.agentkit;
                devCfg = cfg.devshell;
                enabledRuntimes = lib.filterAttrs (_: r: r.enable) cfg._runtimeDevshells;
                aggregatedShellHook = lib.concatStringsSep "\n" (
                  lib.mapAttrsToList (_: r: r.shellHook) enabledRuntimes
                );
                skillPackages = lib.concatLists (
                  lib.mapAttrsToList (_: skill: if skill.enable then skill.packages else [ ]) cfg.skills
                );
              in
              {
                options.agentkit = {
                  enable = lib.mkEnableOption "agentkit";
                  skills = lib.mkOption {
                    type = lib.types.attrsOf agentkitTypes.skill;
                    default = { };
                  };
                  commands = lib.mkOption {
                    type = lib.types.attrsOf agentkitTypes.command;
                    default = { };
                  };
                  devshell = {
                    packages = lib.mkOption {
                      type = lib.types.listOf lib.types.package;
                      default = [ ];
                    };
                    shellHook = lib.mkOption {
                      type = lib.types.str;
                      readOnly = true;
                      default = aggregatedShellHook;
                    };
                    shell = lib.mkOption {
                      type = lib.types.package;
                      readOnly = true;
                      default = pkgs.mkShell {
                        inherit (devCfg) shellHook;
                        packages = devCfg.packages ++ skillPackages;
                      };
                    };
                  };
                  _runtimeDevshells = lib.mkOption {
                    type = lib.types.attrsOf (
                      lib.types.submodule {
                        options = {
                          enable = lib.mkOption {
                            type = lib.types.bool;
                            default = false;
                          };
                          shellHook = lib.mkOption {
                            type = lib.types.str;
                            default = "";
                          };
                          configDir = lib.mkOption {
                            type = lib.types.nullOr lib.types.package;
                            default = null;
                          };
                        };
                      }
                    );
                    default = { };
                  };
                };
              }
            )
            # OpenCode runtime adapter (inlined to avoid mkPerSystemOption)
            (
              { lib, config, ... }:
              let
                cfg = config.agentkit;
                ocCfg = cfg.runtimes.opencode;

                compatibleSkills = lib.filterAttrs (
                  _: skill:
                  skill.enable
                  && skill.path != null
                  && (skill.compatibility == [ ] || builtins.elem "opencode" skill.compatibility)
                ) cfg.skills;

                skillDirs = lib.mapAttrs (_: skill: skill.path) compatibleSkills;
                generatedCommands = lib.mapAttrs (_: ocLib.renderCommand) cfg.commands;
                commandFiles = lib.mapAttrs (
                  name: content: pkgs.writeText "${name}-command.md" content
                ) generatedCommands;

                configDir = pkgs.runCommand "agentkit-opencode-config" { } (
                  ''
                    mkdir -p $out
                  ''
                  + lib.concatStringsSep "\n" (
                    lib.mapAttrsToList (name: dir: ''
                      mkdir -p $out/skills
                      cp -rL ${dir} $out/skills/${name}
                    '') skillDirs
                  )
                  + lib.concatStringsSep "\n" (
                    lib.mapAttrsToList (name: file: ''
                      mkdir -p $out/commands
                      cp ${file} $out/commands/${name}.md
                    '') commandFiles
                  )
                );

                shellHook = ''
                  export OPENCODE_CONFIG_DIR="${configDir}"
                '';
              in
              {
                options.agentkit.runtimes.opencode = {
                  enable = lib.mkEnableOption "OpenCode agent runtime";
                  devshell = {
                    configDir = lib.mkOption {
                      type = lib.types.package;
                      readOnly = true;
                      default = configDir;
                    };
                    shellHook = lib.mkOption {
                      type = lib.types.str;
                      readOnly = true;
                      default = shellHook;
                    };
                    shell = lib.mkOption {
                      type = lib.types.package;
                      readOnly = true;
                      default = pkgs.mkShell { inherit shellHook; };
                    };
                  };
                };

                config.agentkit._runtimeDevshells.opencode = lib.mkIf (cfg.enable && ocCfg.enable) {
                  enable = true;
                  inherit shellHook configDir;
                };
              }
            )
            # The test configuration
            {
              agentkit = {
                enable = true;
                runtimes.opencode.enable = true;
                inherit skills commands;
              };
            }
          ];

          result = (eval.config.perSystem { inherit pkgs lib system; }).agentkit;
        in
        result;

      # ── home-manager target: evaluate the home module ─────────────────
      #
      # We use lib.evalModules to simulate a home-manager evaluation with
      # just enough stub options to evaluate the agentkit home module.
      evalHomeManager =
        {
          skills ? { },
          commands ? { },
        }:
        let
          eval = lib.evalModules {
            modules = [
              ../modules/runtimes/opencode/home-module.nix

              # Stubs for home-manager options that the module writes to
              (
                { lib, ... }:
                {
                  options.home.packages = lib.mkOption {
                    type = lib.types.listOf lib.types.package;
                    default = [ ];
                  };
                  options.programs.opencode = {
                    skills = lib.mkOption {
                      type = lib.types.attrsOf lib.types.path;
                      default = { };
                    };
                    commands = lib.mkOption {
                      type = lib.types.attrsOf lib.types.str;
                      default = { };
                    };
                  };
                }
              )

              # Test configuration
              {
                agentkit = {
                  runtimes.opencode.enable = true;
                  inherit skills commands;
                };
              }
            ];
          };
        in
        eval.config;

      # ── pre-built evaluated configs for the tests ─────────────────────

      # Devshell evaluation with skills
      devshellWithSkills = evalDevshell {
        skills = {
          test-skill = {
            path = fixtures.test-skill;
          };
          minimal-skill = {
            path = fixtures.minimal-skill;
          };
          skill-with-extras = {
            path = fixtures.skill-with-extras;
          };
          disabled-skill = {
            enable = false;
            path = fixtures.test-skill;
          };
        };
      };
      devshellSkillsConfigDir = devshellWithSkills.runtimes.opencode.devshell.configDir;

      # Devshell evaluation with commands
      devshellWithCommands = evalDevshell {
        commands = {
          test-cmd = testCommand;
          deploy = fullCommand;
        };
      };
      devshellCommandsConfigDir = devshellWithCommands.runtimes.opencode.devshell.configDir;

      # Devshell with both skills and commands
      devshellWithBoth = evalDevshell {
        skills = {
          test-skill = {
            path = fixtures.test-skill;
          };
        };
        commands = {
          test-cmd = testCommand;
        };
      };
      devshellBothConfigDir = devshellWithBoth.runtimes.opencode.devshell.configDir;

      # Home-manager evaluation with skills
      hmWithSkills = evalHomeManager {
        skills = {
          test-skill = {
            path = fixtures.test-skill;
          };
          minimal-skill = {
            path = fixtures.minimal-skill;
          };
          skill-with-extras = {
            path = fixtures.skill-with-extras;
          };
          disabled-skill = {
            enable = false;
            path = fixtures.test-skill;
          };
        };
      };

      # Home-manager evaluation with commands
      hmWithCommands = evalHomeManager {
        commands = {
          test-cmd = testCommand;
          deploy = fullCommand;
        };
      };

      # Home-manager with both
      hmWithBoth = evalHomeManager {
        skills = {
          test-skill = {
            path = fixtures.test-skill;
          };
        };
        commands = {
          test-cmd = testCommand;
        };
      };

      # ── pre-rendered command files for lib tests ──────────────────────
      commandFile = pkgs.writeText "test-command.md" (ocLib.renderCommand testCommand);
      fullCommandFile = pkgs.writeText "full-command.md" (ocLib.renderCommand fullCommand);
    in
    {
      checks = {
        # ================================================================
        # lib – pure function unit tests (runtime-agnostic)
        # ================================================================

        # Test command rendering with optional fields omitted
        lib-command-rendering = pkgs.runCommand "agentkit-test-lib-command-rendering" { } ''
          # Frontmatter structure
          head -1 ${commandFile} | grep -q '^---$' || { echo "FAIL: missing opening frontmatter"; exit 1; }
          ${assertFileContains commandFile "description: A test command" "command description"}
          ${assertFileContains commandFile "agent: build" "command agent"}

          # model is null, should not appear
          ${assertFileNotContains commandFile "model:" "null model omitted"}

          # Template content
          ${assertFileContains commandFile "Run the tests" "template content"}
          ${assertFileContains commandFile "ARGUMENTS" "ARGUMENTS placeholder"}

          ${pass "lib-command-rendering"}
        '';

        # Test command rendering with all fields present
        lib-command-rendering-full = pkgs.runCommand "agentkit-test-lib-command-full" { } ''
          ${assertFileContains fullCommandFile "description: Deploy the application" "full description"}
          ${assertFileContains fullCommandFile "agent: build" "full agent"}
          ${assertFileContains fullCommandFile "model: anthropic/claude-sonnet-4-5" "full model"}
          ${assertFileContains fullCommandFile "Deploy to" "full template"}

          ${pass "lib-command-rendering-full"}
        '';

        # ================================================================
        # opencode × devshell × skills
        # ================================================================

        # Skills are installed into configDir/skills/<name>/
        opencode-devshell-skills-installed =
          pkgs.runCommand "agentkit-test-opencode-devshell-skills-installed" { }
            ''
              ${assertDirExists "${devshellSkillsConfigDir}/skills/test-skill" "test-skill dir"}
              ${assertDirExists "${devshellSkillsConfigDir}/skills/minimal-skill" "minimal-skill dir"}
              ${assertDirExists "${devshellSkillsConfigDir}/skills/skill-with-extras" "skill-with-extras dir"}

              ${pass "opencode-devshell-skills-installed"}
            '';

        # SKILL.md content is preserved as-is (not regenerated)
        opencode-devshell-skills-content =
          pkgs.runCommand "agentkit-test-opencode-devshell-skills-content" { }
            ''
              # Full skill: frontmatter + body
              ${assertFileExists "${devshellSkillsConfigDir}/skills/test-skill/SKILL.md" "test-skill SKILL.md"}
              ${assertFileContains "${devshellSkillsConfigDir}/skills/test-skill/SKILL.md" "name: test-skill"
                "test-skill name"
              }
              ${assertFileContains "${devshellSkillsConfigDir}/skills/test-skill/SKILL.md"
                "description: A test skill for verification"
                "test-skill description"
              }
              ${assertFileContains "${devshellSkillsConfigDir}/skills/test-skill/SKILL.md" "license: MIT"
                "test-skill license"
              }
              ${assertFileContains "${devshellSkillsConfigDir}/skills/test-skill/SKILL.md" "audience: developers"
                "test-skill metadata"
              }
              ${assertFileContains "${devshellSkillsConfigDir}/skills/test-skill/SKILL.md" "## What I do"
                "test-skill body heading"
              }
              ${assertFileContains "${devshellSkillsConfigDir}/skills/test-skill/SKILL.md" "Test things"
                "test-skill body content"
              }

              # Minimal skill: just name + description + body
              ${assertFileExists "${devshellSkillsConfigDir}/skills/minimal-skill/SKILL.md" "minimal SKILL.md"}
              ${assertFileContains "${devshellSkillsConfigDir}/skills/minimal-skill/SKILL.md"
                "name: minimal-skill"
                "minimal name"
              }
              ${assertFileContains "${devshellSkillsConfigDir}/skills/minimal-skill/SKILL.md"
                "description: A minimal skill"
                "minimal description"
              }
              ${assertFileContains "${devshellSkillsConfigDir}/skills/minimal-skill/SKILL.md" "Just do the thing."
                "minimal body"
              }

              ${pass "opencode-devshell-skills-content"}
            '';

        # Extra files (scripts/, references/) are preserved
        opencode-devshell-skills-extras =
          pkgs.runCommand "agentkit-test-opencode-devshell-skills-extras" { }
            ''
              ${assertFileExists "${devshellSkillsConfigDir}/skills/skill-with-extras/SKILL.md" "extras SKILL.md"}
              ${assertFileExists "${devshellSkillsConfigDir}/skills/skill-with-extras/scripts/process.sh" "script file"}
              ${assertFileExists "${devshellSkillsConfigDir}/skills/skill-with-extras/references/REFERENCE.md" "reference file"}

              ${assertFileContains "${devshellSkillsConfigDir}/skills/skill-with-extras/SKILL.md"
                "name: skill-with-extras"
                "extras name"
              }
              ${assertFileContains "${devshellSkillsConfigDir}/skills/skill-with-extras/SKILL.md"
                "license: Apache-2.0"
                "extras license"
              }
              ${assertFileContains "${devshellSkillsConfigDir}/skills/skill-with-extras/scripts/process.sh"
                "Processing data"
                "script content"
              }
              ${assertFileContains "${devshellSkillsConfigDir}/skills/skill-with-extras/references/REFERENCE.md"
                "Reference Guide"
                "reference content"
              }

              ${pass "opencode-devshell-skills-extras"}
            '';

        # Disabled skills are excluded from configDir
        opencode-devshell-skills-disabled =
          pkgs.runCommand "agentkit-test-opencode-devshell-skills-disabled" { }
            ''
              # disabled-skill should NOT appear
              if test -d ${devshellSkillsConfigDir}/skills/disabled-skill; then
                echo "FAIL: disabled skill should not be installed"
                exit 1
              fi

              ${pass "opencode-devshell-skills-disabled"}
            '';

        # Shell hook sets OPENCODE_CONFIG_DIR
        opencode-devshell-skills-shellhook =
          pkgs.runCommand "agentkit-test-opencode-devshell-skills-shellhook" { }
            ''
              hook="${devshellWithSkills.runtimes.opencode.devshell.shellHook}"
              echo "$hook" | grep -q 'OPENCODE_CONFIG_DIR' || { echo "FAIL: shellHook missing OPENCODE_CONFIG_DIR"; exit 1; }

              ${pass "opencode-devshell-skills-shellhook"}
            '';

        # ================================================================
        # opencode × devshell × commands
        # ================================================================

        # Commands are installed into configDir/commands/<name>.md
        opencode-devshell-commands-installed =
          pkgs.runCommand "agentkit-test-opencode-devshell-commands-installed" { }
            ''
              ${assertFileExists "${devshellCommandsConfigDir}/commands/test-cmd.md" "test-cmd.md"}
              ${assertFileExists "${devshellCommandsConfigDir}/commands/deploy.md" "deploy.md"}

              ${pass "opencode-devshell-commands-installed"}
            '';

        # Command content has correct frontmatter and template
        opencode-devshell-commands-content =
          pkgs.runCommand "agentkit-test-opencode-devshell-commands-content" { }
            ''
              # test-cmd: partial frontmatter (no model)
              ${assertFileContains "${devshellCommandsConfigDir}/commands/test-cmd.md"
                "description: A test command"
                "test-cmd description"
              }
              ${assertFileContains "${devshellCommandsConfigDir}/commands/test-cmd.md" "agent: build"
                "test-cmd agent"
              }
              ${assertFileNotContains "${devshellCommandsConfigDir}/commands/test-cmd.md" "model:"
                "test-cmd no model"
              }
              ${assertFileContains "${devshellCommandsConfigDir}/commands/test-cmd.md" "ARGUMENTS"
                "test-cmd template"
              }

              # deploy: full frontmatter
              ${assertFileContains "${devshellCommandsConfigDir}/commands/deploy.md"
                "description: Deploy the application"
                "deploy description"
              }
              ${assertFileContains "${devshellCommandsConfigDir}/commands/deploy.md" "agent: build"
                "deploy agent"
              }
              ${assertFileContains "${devshellCommandsConfigDir}/commands/deploy.md"
                "model: anthropic/claude-sonnet-4-5"
                "deploy model"
              }
              ${assertFileContains "${devshellCommandsConfigDir}/commands/deploy.md" "Deploy to"
                "deploy template"
              }

              ${pass "opencode-devshell-commands-content"}
            '';

        # Skills and commands coexist in the same configDir
        opencode-devshell-combined = pkgs.runCommand "agentkit-test-opencode-devshell-combined" { } ''
          ${assertDirExists "${devshellBothConfigDir}/skills/test-skill" "combined skill dir"}
          ${assertFileExists "${devshellBothConfigDir}/commands/test-cmd.md" "combined command file"}

          ${pass "opencode-devshell-combined"}
        '';

        # ================================================================
        # opencode × home-manager × skills
        # ================================================================

        # Skills are passed to programs.opencode.skills as path mappings
        opencode-home-skills-installed =
          pkgs.runCommand "agentkit-test-opencode-home-skills-installed" { }
            (
              let
                hmSkills = hmWithSkills.programs.opencode.skills;
              in
              ''
                # Verify each enabled skill has a path in programs.opencode.skills
                ${assertFileExists "${hmSkills.test-skill}/SKILL.md" "hm test-skill SKILL.md"}
                ${assertFileExists "${hmSkills.minimal-skill}/SKILL.md" "hm minimal-skill SKILL.md"}
                ${assertFileExists "${hmSkills.skill-with-extras}/SKILL.md" "hm skill-with-extras SKILL.md"}

                ${pass "opencode-home-skills-installed"}
              ''
            );

        # Skill content is preserved through home-manager path
        opencode-home-skills-content = pkgs.runCommand "agentkit-test-opencode-home-skills-content" { } (
          let
            hmSkills = hmWithSkills.programs.opencode.skills;
          in
          ''
            ${assertFileContains "${hmSkills.test-skill}/SKILL.md" "name: test-skill" "hm test-skill name"}
            ${assertFileContains "${hmSkills.test-skill}/SKILL.md" "description: A test skill for verification"
              "hm test-skill description"
            }
            ${assertFileContains "${hmSkills.test-skill}/SKILL.md" "## What I do" "hm test-skill body"}

            ${assertFileContains "${hmSkills.minimal-skill}/SKILL.md" "name: minimal-skill" "hm minimal name"}
            ${assertFileContains "${hmSkills.minimal-skill}/SKILL.md" "Just do the thing." "hm minimal body"}

            ${pass "opencode-home-skills-content"}
          ''
        );

        # Extra files are accessible through home-manager skill paths
        opencode-home-skills-extras = pkgs.runCommand "agentkit-test-opencode-home-skills-extras" { } (
          let
            hmSkills = hmWithSkills.programs.opencode.skills;
          in
          ''
            ${assertFileExists "${hmSkills.skill-with-extras}/scripts/process.sh" "hm script file"}
            ${assertFileExists "${hmSkills.skill-with-extras}/references/REFERENCE.md" "hm reference file"}
            ${assertFileContains "${hmSkills.skill-with-extras}/scripts/process.sh" "Processing data"
              "hm script content"
            }
            ${assertFileContains "${hmSkills.skill-with-extras}/references/REFERENCE.md" "Reference Guide"
              "hm reference content"
            }

            ${pass "opencode-home-skills-extras"}
          ''
        );

        # Disabled skills are excluded from programs.opencode.skills
        opencode-home-skills-disabled = pkgs.runCommand "agentkit-test-opencode-home-skills-disabled" { } (
          let
            hmSkills = hmWithSkills.programs.opencode.skills;
            # disabled-skill should not be in the attr set; accessing it
            # would fail evaluation, so we check via attrNames.
            skillNames = builtins.attrNames hmSkills;
            hasDisabled = builtins.elem "disabled-skill" skillNames;
          in
          ''
            ${
              if hasDisabled then
                ''echo "FAIL: disabled skill present in programs.opencode.skills"; exit 1''
              else
                ""
            }

            ${pass "opencode-home-skills-disabled"}
          ''
        );

        # ================================================================
        # opencode × home-manager × commands
        # ================================================================

        # Commands are rendered and passed to programs.opencode.commands
        opencode-home-commands-installed =
          pkgs.runCommand "agentkit-test-opencode-home-commands-installed" { }
            (
              let
                hmCommands = hmWithCommands.programs.opencode.commands;
                testCmdFile = pkgs.writeText "hm-test-cmd.md" hmCommands.test-cmd;
                deployFile = pkgs.writeText "hm-deploy.md" hmCommands.deploy;
              in
              ''
                ${assertFileExists "${testCmdFile}" "hm test-cmd rendered"}
                ${assertFileExists "${deployFile}" "hm deploy rendered"}

                ${pass "opencode-home-commands-installed"}
              ''
            );

        # Command content is correctly rendered for home-manager
        opencode-home-commands-content =
          pkgs.runCommand "agentkit-test-opencode-home-commands-content" { }
            (
              let
                hmCommands = hmWithCommands.programs.opencode.commands;
                testCmdFile = pkgs.writeText "hm-test-cmd.md" hmCommands.test-cmd;
                deployFile = pkgs.writeText "hm-deploy.md" hmCommands.deploy;
              in
              ''
                # test-cmd: partial frontmatter
                ${assertFileContains testCmdFile "description: A test command" "hm test-cmd description"}
                ${assertFileContains testCmdFile "agent: build" "hm test-cmd agent"}
                ${assertFileNotContains testCmdFile "model:" "hm test-cmd no model"}
                ${assertFileContains testCmdFile "ARGUMENTS" "hm test-cmd template"}

                # deploy: full frontmatter
                ${assertFileContains deployFile "description: Deploy the application" "hm deploy description"}
                ${assertFileContains deployFile "model: anthropic/claude-sonnet-4-5" "hm deploy model"}

                ${pass "opencode-home-commands-content"}
              ''
            );

        # Skills and commands coexist in home-manager config
        opencode-home-combined = pkgs.runCommand "agentkit-test-opencode-home-combined" { } (
          let
            hmSkills = hmWithBoth.programs.opencode.skills;
            hmCommands = hmWithBoth.programs.opencode.commands;
            testCmdFile = pkgs.writeText "hm-combined-cmd.md" hmCommands.test-cmd;
          in
          ''
            ${assertFileExists "${hmSkills.test-skill}/SKILL.md" "hm combined skill"}
            ${assertFileExists "${testCmdFile}" "hm combined command"}

            ${pass "opencode-home-combined"}
          ''
        );
      };
    };
}
