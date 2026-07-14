default:
    @just --list

# Evaluate the flake and its outputs.
check:
    nix flake check

# Build the one canonical composition. Use flavour=docker when VMs are unnecessary.
build flavour="vm":
    nix develop --command nxc build -f {{ flavour }} -C hpc::{{ flavour }}

# Build and start the complete ebuffer + ebservice + SLURM topology.
up flavour="vm":
    just build {{ flavour }}
    nix develop --command nxc start -C hpc::{{ flavour }}

# Stop a deployment previously started with `just up`.
down flavour="vm":
    nix develop --command nxc stop -d "deploy/hpc::{{ flavour }}.json"
