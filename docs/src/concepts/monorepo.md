# Monorepo: repository architecture 
> WIP in progress WIP work in wip

This repository is a work in progress for describing and deploying desired
scientific-computing architectures. A composition groups the machines,
services, one or more software modules, and tests needed to reproduce one
architecture.

Today, `mpi-hello` and `openqcd` can run separately, together in
`multi-software-composition`, or with different node-local availability in
`heterogeneous-cluster`.

## Repository map

```text
.
├── flake.nix                 Pins Nix packages and exposes NXC builds
├── flake.lock                Records the exact dependency revisions
├── nxc.json                  Points NXC to the composition catalog
│
├── compositions.nix          Every composition: which apps each node enables
│
├── apps/                     One directory per app
│   ├── default.nix           Imports every app module
│   ├── openmpi.nix           MPI setup shared by the apps
│   ├── mpi-hello/
│   │   ├── default.nix       NixOS module: enable option, package, test fixture
│   │   ├── mpi-hello.c       Source
│   │   ├── mpi-hello.sbatch  SLURM job, usable directly with sbatch
│   │   └── test.nix          NXC test script
│   └── openqcd/              Same shape, plus the openqcd-ym1.in input
│
├── cluster/                  The shared platform, the same for every app
│   ├── topology.nix          Services, SLURM, shared storage, readiness checks
│   ├── ebuffer/              Data-buffer service configuration
│   └── ebservice/            Job-service configuration
│
├── clients/                  Optional; nothing outside reads from here
│   └── python-e2e/           Python client for the ebservice API path, with
│                             its launch scripts
├── scripts/                  Client-neutral helpers (tunnel.sh)
├── docs/                     This book: book.toml, src/, generated book/
└── justfile                  Commands used to build, run, and test
```

Each root folder has one job. The root itself holds only files a tool expects
there (`flake.nix`, `flake.lock`, `nxc.json`, `justfile`) plus
`compositions.nix`, the list of what can be built. Anything every composition
gets goes in `cluster/`, each workload in `apps/`, anything that drives a
running deployment from outside in `clients/`, and helpers that work without
any client in `scripts/`. NXC writes `build/` and `deploy/` into the working
directory.

Every machine imports every app module; each app is off until a composition
enables it:

```text
apps/<name>/  (module with exa-atow.apps.<name>.enable)
  + compositions.nix  (which nodes enable which apps, which test runs)
  + cluster/          (the shared cluster)
  = <name>::<flavour>
```

Compute nodes advertise the apps they enable as SLURM features, so a
composition never lists features separately.
