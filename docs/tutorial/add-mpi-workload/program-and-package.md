# Write and package the application

This chapter creates the two-rank calculator and makes it available as a NixOS
application module. The following chapter adds a profile that places and
validates it.

## 1. Write a tiny two-rank program

Create `nix/modules/applications/mpi-calculator.c`:

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

Create `nix/modules/applications/mpi-calculator.nix`:

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

Do not import this module from `nix/lib/mk-topology.nix`. That constructor owns
the shared topology and must remain application-neutral. Profiles select which
modules are injected into frontend and compute roles.

The next chapter adds this profile entry to `nix/profiles/default.nix` once its
check exists:

```nix
{
  mpi-calculator = {
    modules = [ ../modules/applications/mpi-calculator.nix ];
    check = import ../../checks/nixos/profiles/mpi-calculator.nix;
  };
}
```

Use a profile's `modules` list when a composition installs several existing
modules uniformly:

```nix
multi-software-composition = {
  modules = [
    ../modules/applications/mpi-hello.nix
    ../modules/applications/openqcd.nix
  ];
  check = import ../../checks/nixos/profiles/multi-software-composition.nix;
};
```

For node-local software, use the explicit form. Compute names must match
`compute[1-9][0-9]*`; the optional features become SLURM constraints:

```nix
heterogeneous-cluster = {
  frontendModules = [
    ../modules/applications/mpi-hello.nix
    ../modules/applications/openqcd.nix
  ];
  computeNodes = {
    compute1 = {
      modules = [
        ../modules/applications/mpi-hello.nix
        ../modules/applications/openqcd.nix
      ];
      features = [
        "mpi-hello"
        "openqcd"
      ];
    };
    compute2 = {
      modules = [ ../modules/applications/openqcd.nix ];
      features = [ "openqcd" ];
    };
  };
  check = import ../../checks/nixos/profiles/heterogeneous-cluster.nix;
};
```

Users can target compatible nodes with `srun --constraint=openqcd ...` or an
exact role with `srun --nodelist=compute1 ...`. Multi-node jobs require enough
nodes that share the selected feature.

The module has no composition identity by itself. The next chapter creates the
check and registers both placement and evidence in one profile declaration.

Continue with [Test it through SLURM and NXC](slurm-and-nxc.md).
