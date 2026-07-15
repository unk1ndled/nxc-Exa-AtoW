default:
    @just --list

# Resolve the locally imported SDK packages and download their dependencies.
install:
    nix develop --command uv sync --project examples

# Evaluate the flake and its outputs.
check:
    nix flake check

# Build the one canonical composition. Use flavour=docker when VMs are unnecessary.
build flavour="vm":
    nix develop --command nxc build -f {{ flavour }} -C hpc::{{ flavour }}

# Build and start the complete ebuffer + ebservice + SLURM topology.
up flavour="vm":
    just build {{ flavour }}
    QEMU_OPTS="${QEMU_OPTS:--cpu host}" nix develop --command nxc start -C hpc::{{ flavour }}

# Register the minimal service and run its two-node MPI job through the APIs.
test:
    just tunnel
    nix develop --command e2e-fhs -c "uv run --project examples bash scripts/run-e2e.sh"

# Forward the ebuffer and ebservice APIs from a running VM deployment.
tunnel:
    nix develop --command bash scripts/tunnel.sh

# Stop a deployment previously started with `just up`.
down flavour="vm":
    nix develop --command nxc stop -d "deploy/hpc::{{ flavour }}.json"
