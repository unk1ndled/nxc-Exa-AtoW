# Write and package the application

This chapter creates the two-rank calculator and makes it available as a NixOS
workload module. It deliberately stops before adding the matching NXC test, so
you can see where the repository enforces the package/test contract.

## 1. Write a tiny two-rank program

Create `software/mpi-calculator.c`:

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

Create `software/mpi-calculator.nix`:

```nix
{ pkgs, ... }:
let
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
  imports = [ ./openmpi.nix ];
  environment.systemPackages = [ mpiCalculator ];
}
```

There are two distinct uses of OpenMPI here. `nativeBuildInputs` makes `mpicc`
available while Nix builds the C program. Importing `openmpi.nix` installs the
MPI runtime in the machines and applies the TCP transport settings used by
this VM topology.

Do not import this module directly from `composition.nix`. That file owns the
shared topology and must remain workload-neutral. The catalog selects which
software module is injected into the frontend and compute roles.

Add the new key to `software/default.nix`:

```nix
{
  mpi-calculator = ./mpi-calculator.nix;
  mpi-hello = ./mpi-hello.nix;
  openqcd = ./openqcd.nix;
}
```

When applying these changes incrementally, `just check` should fail at this
moment because the test catalog does not yet contain `mpi-calculator`. That
failure confirms that the catalog guard is working. The next chapter adds the
missing test plug-in and restores successful evaluation.

Continue with [Test it through SLURM and NXC](slurm-and-nxc.md).
