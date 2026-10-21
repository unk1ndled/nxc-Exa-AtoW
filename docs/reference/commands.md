# Command reference

Run `just` with no arguments to list the available recipes. Defaults are
`openqcd` for the workload and `vm` for the flavour.

## Documentation and evaluation

| Command | Effect |
| --- | --- |
| `just check` | Evaluate the flake and validate its outputs with `nix flake check`. |
| `just docs` | Build this mdBook into `book/`. |
| `just docs-serve` | Serve the book on `127.0.0.1:3000` with live reload. |
| `just docs-serve 0.0.0.0 4000` | Override the documentation host and port. Exposing beyond loopback is your responsibility. |

## Dependency setup

| Command | Effect |
| --- | --- |
| `nix develop` | Enter the environment containing NXC, uv, jq, mdBook, and `e2e-fhs`. |
| `just install` | Sync the locked Python dependencies into `e2e/.venv`. |

## Build and deployment

For these recipes the optional argument order is **flavour first, workload
second**:

```text
just build [flavour] [workload]
just up    [flavour] [workload]
just down  [flavour] [workload]
```

| Command | Selected composition |
| --- | --- |
| `just build` | `openqcd::vm` |
| `just build docker` | `openqcd::docker` |
| `just build vm mpi-hello` | `mpi-hello::vm` |
| `just build vm heterogeneous-cluster` | Per-node software composition using the VM flavour. |
| `just up` | Build and start `openqcd::vm` in the foreground. |
| `just up vm mpi-hello` | Build and start `mpi-hello::vm` in the foreground. |
| `just down docker mpi-hello` | Ask NXC to stop the recorded Docker deployment. |

`just up` and the VM test recipe default `QEMU_OPTS` to `-cpu host` only when
the variable is unset. To add other QEMU options, include the CPU choice:

```console
$ QEMU_OPTS="-cpu host <other-options>" just up vm mpi-hello
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
| `just nxc-test mpi-hello` | Run the MPI hello in-topology test. |
| `just nxc-test multi-software-composition` | Run both application jobs in one topology. |
| `just nxc-test heterogeneous-cluster` | Validate node-local packages, SLURM features, and the two-node OpenQCD job. |
| `just tunnel` | Forward a live `openqcd::vm` deployment. |
| `just tunnel mpi-hello` | Forward a live `mpi-hello::vm` deployment. |
| `just test` | Tunnel to a live OpenQCD VM deployment and run its host E2E. |
| `just test mpi-hello` | Tunnel to a live MPI hello VM deployment and run its host E2E. |
| `just test multi-software-composition mpi-hello` | Run the MPI Hello host contract against the combined deployment. |
| `just test multi-software-composition openqcd` | Run the OpenQCD host contract against the combined deployment. |

`just nxc-test` starts its own topology. `just test` expects a matching
`just up` process already running.

## Generated state

| Path | Producer | Purpose |
| --- | --- | --- |
| `build/<workload>::<flavour>.json` | `nxc build` | Description of the built composition. |
| `deploy/<workload>::<flavour>.json` | `nxc start` | Role and VM deployment metadata used by the tunnel. |
| `e2e/.venv/` | `just install` | Locked host E2E environment. |
| `book/` | `just docs` | Generated static documentation. |
| `/tmp/nxc-exa-atow-tunnels-$UID/` | tunnel script | SSH control sockets and selected deployment state. |

Generated repository paths are ignored by Git.
