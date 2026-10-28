# Monorepo: repository architecture 
> WIP in progress WIP work in wip

This repository is a work in progress for describing and deploying desired
scientific-computing architectures. A composition groups the machines,
services, one or more software modules, and tests needed to reproduce one
architecture.

Today the repository ships one composition, `openqcd`. The `mpi-hello` and
`ddf-pipeline` packages are available to enable in any composition, alone,
together, or on only some compute groups.

## Repository map

```text
.
├── flake.nix                 Pins nixpkgs and NXC, applies the overlays, exposes NXC builds
├── flake.lock                Records the exact dependency revisions
├── nxc.json                  Points NXC to the composition catalog
│
├── compositions.nix          Every composition: compute groups and their packages
│
├── pkgs/                     One directory per package
│   ├── packages.nix          Overlay: every package below, by name
│   ├── modules.nix           Imports every exa-atow.pkgs module
│   ├── openmpi.nix           MPI setup shared by the MPI packages
│   ├── mpi-hello/
│   │   ├── package.nix       How to build it
│   │   ├── default.nix       NixOS module: enable and package options, test fixture
│   │   ├── mpi-hello.c       Source
│   │   ├── mpi-hello.sbatch  SLURM job, usable directly with sbatch
│   │   └── test.nix          NXC test script
│   ├── openqcd/              Same shape, plus the openqcd-ym1.in input
│   ├── ddf-pipeline/         DDFacet stack: package.nix, its deps/, a module
│   ├── ebuffer/, ebservice/  Platform services: package.nix, NixOS service module
│   ├── ebhelpers/            Shell helpers for the services: package.nix
│   └── ebsclient/ ...        Python libraries for ebservice: package.nix only
│
├── cluster/                  The system instance, the same for every composition
│   ├── topology.nix          Roles, services, SLURM, shared storage, readiness checks
│   ├── lib.nix               Composition options, compute-node expansion, SLURM
│   │                         node lines, readiness checks used by topology.nix
│   ├── ebuffer/              Data-buffer service configuration
│   └── ebservice/            Job-service configuration
│
├── clients/                  Exa-AToW infrastructure clients (web apps,
│   │                         notebooks, ...); optional, nothing reads from here
│   └── python-e2e/           Python client for the ebservice API path, with
│                             its launch scripts
├── scripts/                  Client-neutral helpers
├── docs/                     This book: book.toml, src/, generated book/
└── justfile                  Commands used to build, run, and test
```

Each root folder has one job. The root itself holds only files a tool expects
there (`flake.nix`, `flake.lock`, `nxc.json`, `justfile`) plus
`compositions.nix`, the list of what can be built. `cluster/` instantiates the
system every composition gets and holds no package definitions; every package,
including the platform services, lives in `pkgs/`; Exa-AToW clients that
drive a running deployment from outside in `clients/`, and helpers that work
without any client in `scripts/`. NXC writes `build/` and `deploy/` into the
working directory.

Inside a package directory, `package.nix` describes how to build the package
and `default.nix` is the NixOS module that installs it; the module never
defines the package itself. Every machine imports every package module; each
is off until a composition enables it:

```text
pkgs/<name>/package.nix   (the package, added to pkgs by pkgs/packages.nix)
pkgs/<name>/default.nix   (module with exa-atow.pkgs.<name>.enable)
  + compositions.nix      (which nodes enable which packages, which test runs)
  + cluster/              (the shared cluster)
  = <name>::<flavour>
```

Compute nodes advertise the packages they enable as SLURM features, so a
composition never lists features separately.
