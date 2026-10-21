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
├── topology.nix              The shared cluster: services, SLURM, readiness checks
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
├── config/                   Runtime configuration for the API services
│   ├── ebuffer/              Data-buffer service configuration
│   └── ebservice/            Job-service configuration
│
├── e2e/                      Optional Python client for the ebservice API path
├── scripts/                  Tunnelling and host E2E launch helpers
└── justfile                  Commands used to build, run, and test
```

Every machine imports every app module; each app is off until a composition
enables it:

```text
apps/<name>/  (module with exa-atow.apps.<name>.enable)
  + compositions.nix  (which nodes enable which apps, which test runs)
  + topology.nix      (the shared cluster)
  = <name>::<flavour>
```

Compute nodes advertise the apps they enable as SLURM features, so a
composition never lists features separately.
