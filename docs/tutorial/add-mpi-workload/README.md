# Add your own MPI workload

This tutorial adds a third composition named `mpi-calculator`. The application
is deliberately small: rank 0 owns the first integer, rank 1 owns the second,
and an MPI reduction adds or multiplies them. Small code lets us concentrate
on the path that a real application follows through this repository.

By the end, the new workload will support both validation layers:

```console
$ just nxc-test mpi-calculator
$ just up vm mpi-calculator
# in another terminal
$ just test mpi-calculator
```

The first command proves that the package, shared filesystem, SLURM, and MPI
work inside the NXC topology. The second test travels through ebuffer and
ebservice, starts the runtime, submits to SLURM over SSH, downloads the result,
and checks its meaning on the host.

This is more than a packaging exercise. An app is part of the repository once
its directory under `apps/` has a Nix module and an in-topology test. The
host-side contract is optional.

## Tutorial map

Work through the chapters in order:

1. [Write and package the application](program-and-package.md) creates the
   MPI program and its Nix module.
2. [Test it through SLURM and NXC](slurm-and-nxc.md) adds a batch example and
   proves the package inside the six-machine topology.
3. [Create the host E2E contract](host-e2e.md) connects the application to
   ebuffer, ebservice, the runtime worker, and output validation.
4. [Run, debug, and adapt the workload](run-and-debug.md) exercises the full
   path and provides a review checklist and troubleshooting guide.

## Before you begin

Run the existing evaluation once from the repository root:

```console
$ just check
```

For the host E2E, also prepare the locked Python environment:

```console
$ just install
```

The examples assume a Linux host with hardware virtualization and the same
Nix setup used in the [quick start](../quickstart.md). The complete VM topology
has six machines and can take several minutes to build for the first time.

## Follow one name through the repository

Choose the app name before creating files. Here it is `mpi-calculator`; the
directory name becomes the composition name.

```text
apps/mpi-calculator/
  ├─ default.nix            NixOS module: package and environment
  ├─ mpi-calculator.c       source
  ├─ mpi-calculator.sbatch  SLURM job
  └─ test.nix               NXC test
        └─> mpi-calculator::vm

Optional host client, only for the ebservice API path:
  e2e/mpi_calculator_e2e.py
  e2e/mpi-calculator-job.ini
  e2e/minimal-e2e.py
```

There is no catalog to register the app in: `compositions.nix` picks up every
directory under `apps/`, and evaluation fails if `test.nix` is missing.

Continue with [Write and package the application](program-and-package.md).
