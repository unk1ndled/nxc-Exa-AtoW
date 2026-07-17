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
| `just up` | Build and start `openqcd::vm` in the foreground. |
| `just up vm mpi-hello` | Build and start `mpi-hello::vm` in the foreground. |
| `just down docker mpi-hello` | Ask NXC to stop the recorded Docker deployment. |

`just up` and the VM test recipe default `QEMU_OPTS` to `-cpu host` only when
the variable is unset. To add other QEMU options, include the CPU choice:

```console
$ QEMU_OPTS="-cpu host <other-options>" just up vm mpi-hello
```

For the pinned NXC release, stop VM deployments with Ctrl-C in the foreground
`just up` terminal. `just down vm ...` reaches an unimplemented
`VmFlavour.cleanup()` path.

## Tests and tunnels

These recipes select a workload only and target the VM path:

| Command | Effect |
| --- | --- |
| `just nxc-test` | Build and run the OpenQCD test inside a temporary VM topology. |
| `just nxc-test mpi-hello` | Run the MPI hello in-topology test. |
| `just tunnel` | Forward a live `openqcd::vm` deployment. |
| `just tunnel mpi-hello` | Forward a live `mpi-hello::vm` deployment. |
| `just test` | Tunnel to a live OpenQCD VM deployment and run its host E2E. |
| `just test mpi-hello` | Tunnel to a live MPI hello VM deployment and run its host E2E. |

`just nxc-test` starts its own topology. `just test` expects a matching
`just up` process already running.

## Generated state

| Path | Producer | Purpose |
| --- | --- | --- |
| `build/<workload>::<flavour>` | `nxc build` | Symlink to the built composition closure. |
| `deploy/<workload>::<flavour>.json` | `nxc start` | Role and VM deployment metadata used by the tunnel. |
| `e2e/.venv/` | `just install` | Locked host E2E environment. |
| `book/` | `just docs` | Generated static documentation. |
| `/tmp/nxc-exa-atow-tunnels-$UID/` | tunnel script | SSH control sockets and selected deployment state. |

Generated repository paths are ignored by Git.
