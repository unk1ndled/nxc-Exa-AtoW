# canonical Exa-AtoW with nxc
Proof of concept and canonical example for deploying Exa-AtoW style HPC infrastructure using NixOS-Compose.

## Architecture

```mermaid
flowchart LR
    subgraph Host[Developer machine]
        Client[E2E client]
        Runtime[Runtime worker]
    end

    subgraph APIs[EB API layer]
        Service[ebservice<br/>Jobs and runtimes]
        Buffer[ebuffer<br/>Input and output data]
    end

    subgraph SLURM[Shared SLURM topology]
        Frontend[Frontend<br/>Selected workload]
        Controller[Controller<br/>Scheduling]
        Compute1[Compute 1<br/>MPI rank 0]
        Compute2[Compute 2<br/>MPI rank 1]
        Users[Shared /users storage]

        Frontend -->|Submit job| Controller
        Controller -->|Start task| Compute1
        Controller -->|Start task| Compute2
        Frontend --- Users
        Compute1 --- Users
        Compute2 --- Users
    end

    Client -->|Register and submit| Service
    Client <-->|Upload and download| Buffer
    Runtime -->|Poll jobs and report status| Service
    Runtime -->|Read and fill buffers| Buffer
    Runtime -->|SSH through localhost:2222| Frontend
```

This repository exposes four NixOS-Compose compositions over one shared HPC
topology:

- `openqcd` (the default) runs a small, real OpenQCD 2.0 HMC workload;
- `mpi-hello` is a fast two-node MPI diagnostic;
- `multi-software-composition` installs and validates both applications;
- `heterogeneous-cluster` installs MPI Hello only on `compute1` while keeping
  OpenQCD on both compute nodes.

Every composition deploys ebuffer, ebservice, a SLURM frontend and controller,
and one or more named compute nodes. Catalog entries can apply the same modules
to every node or select modules and SLURM features per compute node.

To integrate another application, follow the step-by-step
[mdBook tutorial](docs/tutorial/quickstart.md).


## Repository model

The implementation uses the Nix-native progression from capabilities to
compositions to evidence:

| Concept | Location | Responsibility |
| --- | --- | --- |
| Modules | `nix/modules/` | Reusable application capabilities with no composition identity. |
| Profiles | `nix/profiles/default.nix` | Named module placement plus the NXC check proving that placement. |
| Constructors | `nix/lib/` | Profile validation and assembly of the shared API, storage, and SLURM topology. |
| Checks | `checks/nixos/` and `checks/host/` | In-topology assertions and host API-to-SLURM contracts. |
| Tools | `tools/` | VM and Grid'5000 operational adapters used by the `justfile`. |

There is one profile catalog, not separate software and test registries. A
uniform profile declares `modules`; a heterogeneous profile declares
`frontendModules` and `computeNodes`; every profile declares `check` beside its
placement. `nix/lib/mk-compositions.nix` normalizes that schema and passes it to
`nix/lib/mk-topology.nix`.



## End-to-end behavior

The default `just test` path:

1. authenticates with ebservice;
2. registers the OpenQCD microservice and compatible runtime;
3. uploads `checks/host/openqcd-ym1.in` and creates scheduler and output ebuffers;
4. submits a two-node SLURM job through the frontend;
5. runs one `ym1` rank on each compute VM;
6. returns `openqcd-e2e.log` through ebuffer;
7. validates the lattice and process grid, one trajectory, configuration
   export, and a finite plaquette on the client.

`just test mpi-hello` follows the same shared lifecycle without an input
ebuffer. It returns `mpi-hello.out` and requires ranks 0 and 1 to report from
two distinct compute hosts.

These tests cover the current local package, API, shared-storage, SLURM, MPI,
and output-transfer paths. They do not establish production security,
persistent storage, normal remote SCP, full scheduler accounting, large
transfers, non-VM E2E behavior, portable CPU emulation, failure recovery, or
concurrent multi-user behavior.

See the [development notes](docs/DevNotes.md) for the local compatibility
adapters and testing shortcuts.



## Commands

The default flavour is `vm` and the default workload is `openqcd`. For
`build`, `up`, and `down`, the flavour remains the first optional argument and
the workload is second:

```console
just up                            # openqcd::vm
just up vm mpi-hello               # mpi-hello::vm

just down docker                  # stop openqcd::docker
```

The two test layers select only a workload because they exercise the VM
flavour:

```console
just nxc-test                      # OpenQCD in-topology integration test
just nxc-test mpi-hello
just nxc-test multi-software-composition

just tunnel                        # expose the running OpenQCD VM
just tunnel mpi-hello

just test                          # OpenQCD API-to-SLURM host E2E
just test mpi-hello
just test multi-software-composition mpi-hello
just test multi-software-composition openqcd
```

`just nxc-test` builds the selected composition and runs its test from inside
NXC. `just test` expects that composition's VM deployment to be running,
establishes its tunnels, and launches the selected application's host E2E. Its
second argument defaults to the composition name for single-application
compositions. Use `just install` once to create `checks/host/.venv` from the locked
dependencies.

For the pinned NXC version, stop a VM deployment by interrupting its foreground
`just up` process with Ctrl-C. Its standalone VM stop path calls a missing
`VmFlavour.cleanup()` method; `just down` remains available for flavours such
as Docker that implement cleanup.




## Documentation

The repository includes a full mdBook with separate concepts, architecture,
tutorial, and reference sections:

```console
just docs
just docs-serve
```

The generated site is written to `book/`; the live server defaults to
`http://127.0.0.1:3000`. Start at the
[book introduction](docs/README.md) or browse its
[table of contents](docs/SUMMARY.md).

Commits to the default branch publish the book on
[GitHub Pages](https://unk1ndled.github.io/nxc-Exa-AtoW/).
