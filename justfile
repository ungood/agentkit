default:
    @just --list

# Format all files
format:
    nix fmt

# Run flake checks
check:
    nix flake check

# Update flake inputs
update:
    nix flake update

# Enter dev shell
shell:
    nix develop

# Build test derivations
test:
    nix flake check -L
