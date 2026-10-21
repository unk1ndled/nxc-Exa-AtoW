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
its module is imported from `apps/default.nix` and a composition in
`compositions.nix` enables it and runs its in-topology test. The host-side
contract is optional.

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

Choose the app name before creating files. Here it is `mpi-calculator`; it
names the directory, the `exa-atow.apps.mpi-calculator` options, the SLURM
feature, and the composition.

```text
apps/mpi-calculator/
  ├─ default.nix            NixOS module: enable option, package, test fixture
  ├─ mpi-calculator.c       source
  ├─ mpi-calculator.sbatch  SLURM job
  └─ test.nix               NXC test script
apps/default.nix            imports ./mpi-calculator
compositions.nix            mpi-calculator = topology { ... };
        └─> mpi-calculator::vm

Optional host client, only for the ebservice API path:
  clients/python-e2e/mpi_calculator_e2e.py
  clients/python-e2e/mpi-calculator-job.ini
  clients/python-e2e/minimal-e2e.py
```

Nothing is discovered automatically. `apps/default.nix` lists every app
module, and `compositions.nix` lists every composition; adding the app is one
line in the first and one entry in the second.

Continue with [Write and package the application](program-and-package.md).
