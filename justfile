default:
    @just --list

# Resolve the locally imported SDK packages and download their dependencies.
install:
    nix develop --command uv sync --project e2e

# Evaluate the flake and its outputs.
check:
    nix flake check

# Build the mdBook documentation into book/.
docs:
    nix develop --command mdbook build

# Serve the mdBook documentation with live reload.
docs-serve hostname="127.0.0.1" port="3000":
    nix develop --command mdbook serve --hostname "{{ hostname }}" --port "{{ port }}"

# Build one workload composition. The flavour stays first for `just build docker` compatibility.
build flavour="vm" workload="openqcd":
    nix develop --command nxc build -f "{{ flavour }}" -C "{{ workload }}::{{ flavour }}"

# Build and start the shared topology with one selected workload.
up flavour="vm" workload="openqcd":
    just build "{{ flavour }}" "{{ workload }}"
    QEMU_OPTS="${QEMU_OPTS:--cpu host}" nix develop --command nxc start -C "{{ workload }}::{{ flavour }}"

# Run the selected workload's NXC integration test inside the topology.
nxc-test workload="openqcd":
    just build vm "{{ workload }}"
    QEMU_OPTS="${QEMU_OPTS:--cpu host}" nix develop --command nxc start -t -C "{{ workload }}::vm"

# Run the selected workload's API-to-SLURM host E2E against its VM composition.
test workload="openqcd":
    just tunnel "{{ workload }}"
    nix develop --command e2e-fhs -c "uv run --project e2e bash scripts/run-e2e.sh '{{ workload }}'"

# Forward APIs and frontend SSH from the selected VM composition.
tunnel workload="openqcd":
    nix develop --command bash scripts/tunnel.sh "deploy/{{ workload }}::vm.json"

# Stop through NXC when the selected flavour implements standalone cleanup.
down flavour="vm" workload="openqcd":
    nix develop --command nxc stop -d "deploy/{{ workload }}::{{ flavour }}.json"
