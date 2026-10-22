# Write and package the application

This chapter creates the two-rank calculator and makes it available as a NixOS
app module. The next chapter adds the matching NXC test.

## 1. Write a tiny two-rank program

Create `apps/mpi-calculator/mpi-calculator.c`:

```c
#include <errno.h>
#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
  int rank;
  int size;
  char host[MPI_MAX_PROCESSOR_NAME];
  int host_length;

  MPI_Init(&argc, &argv);
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  MPI_Comm_size(MPI_COMM_WORLD, &size);

  if (size != 2) {
    if (rank == 0) {
      fprintf(stderr, "mpi-calculator requires exactly two MPI ranks\n");
    }
    MPI_Abort(MPI_COMM_WORLD, 2);
  }

  if (argc != 4) {
    if (rank == 0) {
      fprintf(stderr, "usage: mpi-calculator add|multiply LEFT RIGHT\n");
    }
    MPI_Abort(MPI_COMM_WORLD, 2);
  }

  MPI_Op reduction;
  if (strcmp(argv[1], "add") == 0) {
    reduction = MPI_SUM;
  } else if (strcmp(argv[1], "multiply") == 0) {
    reduction = MPI_PROD;
  } else {
    if (rank == 0) {
      fprintf(stderr, "unknown operation: %s\n", argv[1]);
    }
    MPI_Abort(MPI_COMM_WORLD, 2);
  }

  errno = 0;
  char *end = NULL;
  long operand = strtol(argv[rank + 2], &end, 10);
  if (errno != 0 || end == argv[rank + 2] || *end != '\0') {
    fprintf(stderr, "rank %d received an invalid integer\n", rank);
    MPI_Abort(MPI_COMM_WORLD, 2);
  }

  long result = 0;
  MPI_Reduce(&operand, &result, 1, MPI_LONG, reduction, 0, MPI_COMM_WORLD);
  MPI_Get_processor_name(host, &host_length);

  /* Print in rank order so logs are pleasant to read. */
  for (int turn = 0; turn < size; ++turn) {
    MPI_Barrier(MPI_COMM_WORLD);
    if (rank == turn) {
      printf("rank %d operand %ld on %s\n", rank, operand, host);
      fflush(stdout);
    }
  }
  MPI_Barrier(MPI_COMM_WORLD);

  if (rank == 0) {
    printf("result %s = %ld\n", argv[1], result);
  }

  MPI_Finalize();
  return 0;
}
```

Every rank receives the same command line, but selects a different operand
with `argv[rank + 2]`. `MPI_Reduce` is the distributed part of the calculator:
the two local values become one result on rank 0. The program requires exactly
two ranks so that an accidentally changed SLURM request fails loudly instead
of producing plausible but misleading output.

The host names in the output are also part of the contract. They let the tests
prove that SLURM placed one rank on each compute node rather than running two
processes on one node.

## 2. Package and install the program with Nix

Create `apps/mpi-calculator/default.nix`:

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.exa-atow.apps.mpi-calculator;

  mpiCalculator = pkgs.stdenv.mkDerivation {
    pname = "mpi-calculator";
    version = "1.0";
    src = ./mpi-calculator.c;
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.openmpi ];

    buildPhase = ''
      runHook preBuild
      mpicc "$src" -o mpi-calculator
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 mpi-calculator "$out/bin/mpi-calculator"
      runHook postInstall
    '';
  };
in
{
  options.exa-atow.apps.mpi-calculator.enable =
    lib.mkEnableOption "the MPI calculator example";

  config = lib.mkIf cfg.enable {
    exa-atow.openmpi.enable = true;
    environment.systemPackages = [ mpiCalculator ];
  };
}
```

There are two distinct uses of OpenMPI here. `nativeBuildInputs` makes `mpicc`
available while Nix builds the C program. Setting `exa-atow.openmpi.enable`
turns on `apps/openmpi.nix`, which installs the MPI runtime in the machines
and applies the TCP transport settings used by this VM topology.

Every machine imports every app module, so the option exists everywhere, but
the module does nothing until a composition sets
`exa-atow.apps.mpi-calculator.enable = true`.

Add the directory to `apps/default.nix`:

```nix
imports = [
  ./openmpi.nix
  ./mpi-calculator
  ./mpi-hello
  ./openqcd
];
```

Then add a composition to `compositions.nix` that enables the app on the
frontend and on a group of two compute nodes:

```nix
mpi-calculator = topology {
  frontend.exa-atow.apps.mpi-calculator.enable = true;
  computeGroups.compute = {
    count = 2;
    node.exa-atow.apps.mpi-calculator.enable = true;
  };
  testScript = "";
};
```

Do not install the app from `cluster/topology.nix`. That file owns the shared
topology and must remain app-neutral; compositions decide which apps are
enabled where.

`computeGroups.compute` with `count = 2` becomes the nodes `compute1` and
`compute2`, all configured by the same `node`; change `count` to resize the
group. For different apps on different nodes, declare one group per node type, as in
the [quick start](../quickstart.md#3-declare-your-own-cluster). Group names are
lowercase words joined by `-`, and each compute node advertises the apps it
enables as SLURM features:

```nix
computeGroups = {
  mixed = {
    count = 1;
    node.exa-atow.apps = {
      mpi-hello.enable = true;
      openqcd.enable = true;
    };
  };
  compute = {
    count = 1;
    node.exa-atow.apps.openqcd.enable = true;
  };
};
```

Users can target compatible nodes with `srun --constraint=openqcd ...` or an
exact node with `srun --nodelist=mixed1 ...`. Multi-node jobs require enough
nodes that share the selected feature.

`just check` now passes, and the composition runs only the shared readiness
checks. The next chapter gives it a real test.

Continue with [Test it through SLURM and NXC](slurm-and-nxc.md).
