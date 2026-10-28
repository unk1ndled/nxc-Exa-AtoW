# Every recipe line runs inside the flake's development shell.
set shell := ["nix", "develop", "--command", "bash", "-euc"]

export QEMU_OPTS := env("QEMU_OPTS", "-cpu host")

default:
    @just --list

# Evaluate the flake and its outputs.
check:
    nix flake check

# Build the mdBook documentation into docs/book/.
docs:
    mdbook build docs

# Serve the documentation on 127.0.0.1:3000 with live reload.
docs-serve:
    mdbook serve docs

# Build one composition, e.g. `just build docker openqcd`.
build flavour="vm" composition="openqcd":
    nxc build -f {{ flavour }} -C {{ composition }}::{{ flavour }}

# Build and start the topology in the foreground.
up flavour="vm" composition="openqcd": (build flavour composition)
    nxc start -C {{ composition }}::{{ flavour }}

# Stop a deployment (the VM flavour has no cleanup; use Ctrl-C on `just up`).
down flavour="vm" composition="openqcd":
    nxc stop -d deploy/{{ composition }}::{{ flavour }}.json

# Build and run the composition's NXC test in temporary VMs.
nxc-test composition="openqcd": (build "vm" composition)
    nxc start -t -C {{ composition }}::vm

# Forward the APIs and frontend SSH of a running VM deployment.
tunnel composition="openqcd":
    bash scripts/tunnel.sh deploy/{{ composition }}::vm.json

[group('optional')]
install:
    uv sync --project clients/python-e2e
test composition="openqcd" application=composition: (tunnel composition)
    e2e-fhs -c "uv run --project clients/python-e2e bash clients/python-e2e/run-e2e.sh {{ application }} vm-tunnel deploy/{{ composition }}::vm.json {{ composition }}"

[script("bash")]
g5k-e2e composition="openqcd" application=composition walltime="1:00:00" duration="1h":
    bash clients/python-e2e/g5k-e2e.sh {{ composition }} {{ application }} {{ walltime }} {{ duration }}
