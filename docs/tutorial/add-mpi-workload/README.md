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

This is more than a packaging exercise. A workload is considered part of the
repository only when it has an executable, a composition catalog entry, an
in-topology test, and a host-side application contract.

## Tutorial map

Work through the chapters in order:

1. [Write and package the application](program-and-package.md) creates the
   MPI program, its Nix derivation, and the software catalog entry.
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

Choose the workload name before creating files. Here the composition name is
`mpi-calculator`, while Python uses the equivalent module name
`mpi_calculator_e2e.py`.

```text
software/default.nix ─┐
                     ├─> mpi-calculator::vm
e2e/nxc/default.nix ──┘

mpi-calculator::vm
        ├─ package:       software/mpi-calculator.nix
        ├─ NXC test:      e2e/nxc/mpi-calculator.nix
        ├─ batch example: examples/mpi-calculator.sbatch
        └─ host contract:
             e2e/mpi_calculator_e2e.py
             e2e/mpi-calculator-job.ini
             e2e/minimal-e2e.py
```

The two Nix catalogs must contain exactly the same keys. This is intentional:
`compositions.nix` refuses to evaluate a package that has no deployment test.
That early failure is useful when a file has been added but not registered.

Continue with [Write and package the application](program-and-package.md).
