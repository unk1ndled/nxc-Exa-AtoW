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

# Build one composition. The flavour stays first for `just build docker` compatibility.
build flavour="vm" workload="openqcd":
    nix develop --command nxc build -f "{{ flavour }}" -C "{{ workload }}::{{ flavour }}"

# Build and start the shared topology with one selected composition.
up flavour="vm" workload="openqcd":
    just build "{{ flavour }}" "{{ workload }}"
    QEMU_OPTS="${QEMU_OPTS:--cpu host}" nix develop --command nxc start -C "{{ workload }}::{{ flavour }}"

# Run the selected composition's NXC integration test inside the topology.
nxc-test workload="openqcd":
    just build vm "{{ workload }}"
    QEMU_OPTS="${QEMU_OPTS:--cpu host}" nix develop --command nxc start -t -C "{{ workload }}::vm"

# Run one application's API-to-SLURM host E2E against the selected VM composition.
# The optional application argument is useful when a composition contains several packages.
test workload="openqcd" application=workload:
    just tunnel "{{ workload }}"
    nix develop --command e2e-fhs -c "uv run --project e2e bash scripts/run-e2e.sh '{{ application }}' vm-tunnel 'deploy/{{ workload }}::vm.json' '{{ workload }}'"

# Build a physical Grid'5000 deployment from a site frontend.
g5k-build workload="openqcd":
    nix develop --command nxc build -f g5k-nfs-store -C "{{ workload }}::g5k-nfs-store"

# Run embedded topology checks after the non-interactive kexec deployment.
g5k-check workload="openqcd":
    nix develop --command nxc driver -t -d "deploy/{{ workload }}::g5k-nfs-store.json"

# Run the host API-to-SLURM scenario directly from the Grid'5000 frontend.
g5k-test workload="openqcd" application=workload:
    nix develop --command bash scripts/run-g5k-test.sh "{{ workload }}" "{{ application }}" "deploy/{{ workload }}::g5k-nfs-store.json"

# Build, reserve, deploy, validate, run the host E2E, and always release the job.
g5k-e2e workload="openqcd" application=workload walltime="1:00:00" duration="1h":
    bash scripts/g5k-e2e.sh "{{ workload }}" "{{ application }}" "{{ walltime }}" "{{ duration }}"

# Forward APIs and frontend SSH from the selected VM composition.
tunnel workload="openqcd":
    nix develop --command bash scripts/tunnel.sh "deploy/{{ workload }}::vm.json"

# Stop through NXC when the selected flavour implements standalone cleanup.
down flavour="vm" workload="openqcd":
    nix develop --command nxc stop -d "deploy/{{ workload }}::{{ flavour }}.json"
