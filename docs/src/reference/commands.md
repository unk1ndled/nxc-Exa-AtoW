# Command reference

Run `just` with no arguments to list the available recipes. Defaults are
`openqcd` for the composition and `vm` for the flavour. Every recipe runs its
command inside `nix develop`, so the justfile reads as plain `nix`, `nxc`, and
`mdbook` calls.

## Documentation and evaluation

| Command | Effect |
| --- | --- |
| `just check` | Evaluate the flake and validate its outputs with `nix flake check`. |
| `just docs` | Build this mdBook into `docs/book/`. |
| `just docs-serve` | Serve the book on `127.0.0.1:3000` with live reload. |

## Dependency setup

| Command | Effect |
| --- | --- |
| `nix develop` | Enter the environment containing NXC, uv, jq, mdBook, and `e2e-fhs`. |
| `just install` | Sync the locked Python dependencies into `clients/python-e2e/.venv`. |

## Build and deployment

For these recipes the optional argument order is **flavour first, composition
second**:

```text
just build [flavour] [composition]
just up    [flavour] [composition]
just down  [flavour] [composition]
```

| Command | Selected composition |
| --- | --- |
| `just build` | `openqcd::vm` |
| `just build docker` | `openqcd::docker` |
| `just build vm my-cluster` | `my-cluster::vm`, for a composition you added to `compositions.nix`. |
| `just up` | Build and start `openqcd::vm` in the foreground. |
| `just down docker` | Ask NXC to stop the recorded Docker deployment. |

`just up` and the VM test recipe default `QEMU_OPTS` to `-cpu host` only when
the variable is unset. To add other QEMU options, include the CPU choice:

```console
$ QEMU_OPTS="-cpu host <other-options>" just up
```

Stop VM deployments with Ctrl-C in the foreground `just up` terminal.
`just down vm ...` does nothing, because NXC's VM flavour has no standalone
cleanup.

## Tests and tunnels

These recipes target the VM path. `just test` accepts a composition followed
by an optional application; the application defaults to the composition name.

| Command | Effect |
| --- | --- |
| `just nxc-test` | Build and run the OpenQCD test inside a temporary VM topology. |
| `just tunnel` | Forward a live `openqcd::vm` deployment. |
| `just test` | Tunnel to a live OpenQCD VM deployment and run its host E2E. |
| `just test my-cluster mpi-hello` | Run the MPI Hello host contract against a running `my-cluster::vm` that enables it. |

`just nxc-test` starts its own topology. `just test` expects a matching
`just up` process already running.

## Generated state

| Path | Producer | Purpose |
| --- | --- | --- |
| `build/<workload>::<flavour>.json` | `nxc build` | Description of the built composition. |
| `deploy/<workload>::<flavour>.json` | `nxc start` | Role and VM deployment metadata used by the tunnel. |
| `clients/python-e2e/.venv/` | `just install` | Locked host E2E environment. |
| `docs/book/` | `just docs` | Generated static documentation. |
| `/tmp/nxc-exa-atow-tunnels-$UID/` | tunnel script | SSH control sockets and selected deployment state. |

Generated repository paths are ignored by Git.
