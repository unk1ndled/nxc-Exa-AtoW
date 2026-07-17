# Monorepo: repository architecture 
> WIP in progress WIP work in wip

This repository is a work in progress for describing and deploying desired
scientific-computing architectures. A composition groups the machines,
services, workload, and tests needed to reproduce one architecture.

Today, `mpi-hello` and `openqcd` share the same six-machine topology. They are
the first two examples, not the final scope of the monorepo.

## Repository map

```text
.
├── flake.nix                 Pins Nix packages and exposes NXC builds
├── flake.lock                Records the exact dependency revisions
├── nxc.json                  Points NXC to the composition catalog
│
├── composition.nix           Defines the shared machine topology
├── compositions.nix          Joins each workload to its matching test
│
├── software/                 Packages installed on frontend and compute nodes
│   ├── default.nix           Catalog of available workload names
│   ├── openmpi.nix           MPI setup shared by the workloads
│   ├── mpi-hello.nix         MPI hello package and environment
│   └── openqcd.nix           OpenQCD package and environment
│
├── config/                   Runtime configuration for the API services
│   ├── ebuffer/              Data-buffer service configuration
│   └── ebservice/            Job-service configuration
│
├── e2e/                      Evidence that a deployed architecture works
│   ├── nxc/                  Tests run from inside an NXC deployment
│   │   ├── default.nix       Test catalog; mirrors software/default.nix
│   │   ├── common.nix        Checks shared by every workload
│   │   ├── mpi-hello.nix     MPI hello deployment checks
│   │   └── openqcd.nix       OpenQCD deployment checks
│   ├── common.py             Shared host-side job lifecycle
│   ├── minimal-e2e.py        Selects the workload contract
│   ├── *_e2e.py              Workload-specific API and output checks
│   └── *-job.ini             Workload command and SLURM resources
│
├── examples/                 Batch scripts for direct SLURM use
├── scripts/                  Tunnelling and host E2E launch helpers
└── justfile                  Commands used to build, run, and test
```

The two catalogs are the main assembly point:

```text
software/<name>.nix
        +
e2e/nxc/<name>.nix
        +
composition.nix
        =
<name>::<deployment flavour>
```

`software/default.nix` and `e2e/nxc/default.nix` must expose the same names.
Evaluation fails when a workload has no matching deployment test.
