# TODO

## Done

- [x] Rename `directory` → `path` in skill type and all consumers
- [x] Add `packages` field to skill type
- [x] Move all agentkit options to perSystem (skills, commands, enable, runtimes)
- [x] Auto-aggregate skill packages into devshell
- [x] Bundle built-in skills (tldr) into flakeModules.default
- [x] Rename homeModules.opencode → homeModules.default
- [x] Auto-enable devshell when a runtime is enabled (no manual enable toggles)
- [x] Update home-manager module to use full skill type with packages
- [x] Update README, examples, and docs to match new API

## Remaining

### Home-manager module

- The home-manager module needs real-world testing with an actual
  home-manager setup. It references `programs.opencode` which is not
  a standard home-manager option — this will need a proper OpenCode
  home-manager module (either upstream or as part of agentkit).

### Future runtimes

- **Claude Code adapter** — planned but not implemented.
- Runtime adapter interface should be documented once a second runtime
  exists to validate the pattern.

### Testing

- Add integration tests that exercise the full perSystem evaluation
  (currently tests only check skill directory copying and command rendering).
- Test the skill `packages` aggregation.
- Test compatibility filtering end-to-end.
