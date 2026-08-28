[private]
default:
    @just --list

# Sync development dependencies.
[group('Project')]
install:
    nix develop --command uv sync --project checks/host

# Validate flake outputs.
[group('Project')]
check:
    nix flake check

# Build the documentation.
[group('Documentation')]
docs:
    nix develop --command mdbook build

# Serve the documentation locally.
[group('Documentation')]
docs-serve hostname="127.0.0.1" port="3000":
    nix develop --command mdbook serve --hostname "{{ hostname }}" --port "{{ port }}"

# Build a composition.
[group('Local deployment')]
build flavour="vm" workload="openqcd":
    nix develop --command nxc build -f "{{ flavour }}" -C "{{ workload }}::{{ flavour }}"

# Build and start a composition.
[group('Local deployment')]
up flavour="vm" workload="openqcd":
    just build "{{ flavour }}" "{{ workload }}"
    QEMU_OPTS="${QEMU_OPTS:--cpu host}" nix develop --command nxc start -C "{{ workload }}::{{ flavour }}"

# Run an in-topology test.
[group('Testing')]
nxc-test workload="openqcd":
    just build vm "{{ workload }}"
    QEMU_OPTS="${QEMU_OPTS:--cpu host}" nix develop --command nxc start -t -C "{{ workload }}::vm"

# Run a host E2E against a live VM.
[group('Testing')]
test workload="openqcd" application=workload:
    just tunnel "{{ workload }}"
    nix develop --command e2e-fhs -c "uv run --project checks/host bash tools/host/run-e2e.sh '{{ application }}' vm-tunnel 'deploy/{{ workload }}::vm.json' '{{ workload }}'"

# Build a Grid'5000 deployment.
[group("Grid'5000")]
g5k-build workload="openqcd":
    nix develop --command nxc build -f g5k-nfs-store -C "{{ workload }}::g5k-nfs-store"

# Run Grid'5000 topology checks.
[group("Grid'5000")]
g5k-check workload="openqcd":
    nix develop --command nxc driver -t -d "deploy/{{ workload }}::g5k-nfs-store.json"

# Run a Grid'5000 host E2E.
[group("Grid'5000")]
g5k-test workload="openqcd" application=workload:
    nix develop --command bash tools/grid5000/run-test.sh "{{ workload }}" "{{ application }}" "deploy/{{ workload }}::g5k-nfs-store.json"

[group("Grid'5000")]
g5k-e2e workload="openqcd" application=workload walltime="1:00:00" duration="1h":
    bash tools/grid5000/e2e.sh "{{ workload }}" "{{ application }}" "{{ walltime }}" "{{ duration }}"

# Open VM service tunnels.
[group('Local deployment')]
tunnel workload="openqcd":
    nix develop --command bash tools/vm/tunnel.sh "deploy/{{ workload }}::vm.json"

# Stop a composition.
[group('Local deployment')]
down flavour="vm" workload="openqcd":
    nix develop --command nxc stop -d "deploy/{{ workload }}::{{ flavour }}.json"
