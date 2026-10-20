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
├── compositions.nix          Turns apps/ and compositions/ into NXC compositions
│
├── apps/                     One directory per app; each becomes a composition
│   ├── openmpi.nix           MPI setup shared by the apps
│   ├── mpi-hello/
│   │   ├── default.nix       NixOS module: package and environment
│   │   ├── mpi-hello.c       Source
│   │   ├── mpi-hello.sbatch  SLURM job, usable directly with sbatch
│   │   └── test.nix          NXC test: job fixture and assertions
│   └── openqcd/              Same shape, plus the openqcd-ym1.in input
│
├── compositions/             Compositions that combine several apps
│   ├── multi-software-composition.nix  Both apps on every node
│   └── heterogeneous-cluster.nix       Different apps per compute node
│
├── config/                   Runtime configuration for the API services
│   ├── ebuffer/              Data-buffer service configuration
│   └── ebservice/            Job-service configuration
│
├── e2e/                      Optional Python client for the ebservice API path
├── scripts/                  Tunnelling and host E2E launch helpers
└── justfile                  Commands used to build, run, and test
```

Compositions are assembled without a hand-maintained catalog:

```text
apps/<name>/default.nix + apps/<name>/test.nix + topology.nix = <name>::<flavour>
compositions/<name>.nix                        + topology.nix = <name>::<flavour>
```

Adding a directory under `apps/` is enough to get a new composition.
