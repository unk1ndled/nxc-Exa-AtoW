# Write and package the application

This chapter creates the two-rank calculator and makes it available as a NixOS
app module. The next chapter adds the matching NXC test.

## 1. Write a tiny two-rank program

Create `pkgs/mpi-calculator/mpi-calculator.c`:

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

A package directory keeps two things apart: `package.nix` says how to build the
program, and `default.nix` is the NixOS module that installs it.

Create `pkgs/mpi-calculator/package.nix`:

```nix
{ stdenv, openmpi }:

stdenv.mkDerivation {
  pname = "mpi-calculator";
  version = "1.0";
  src = ./mpi-calculator.c;
  dontUnpack = true;
  nativeBuildInputs = [ openmpi ];

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
}
```

Add it to the overlay in `pkgs/packages.nix`, which makes it `pkgs.mpi-calculator`
everywhere and `nix build .#mpi-calculator` once it is also listed under
`packages` in `flake.nix`:

```nix
mpi-calculator = prev.callPackage ./mpi-calculator/package.nix { };
```

Then create the module, `pkgs/mpi-calculator/default.nix`:

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.exa-atow.pkgs.mpi-calculator;
in
{
  options.exa-atow.pkgs.mpi-calculator = {
    enable = lib.mkEnableOption "the MPI calculator example";
    package = lib.mkPackageOption pkgs "mpi-calculator" { };
  };

  config = lib.mkIf cfg.enable {
    exa-atow.openmpi.enable = true;
    environment.systemPackages = [ cfg.package ];
  };
}
```

There are two distinct uses of OpenMPI here. `nativeBuildInputs` makes `mpicc`
available while Nix builds the C program. Setting `exa-atow.openmpi.enable`
turns on `pkgs/openmpi.nix`, which installs the MPI runtime in the machines
and applies the TCP transport settings used by this VM topology.

Every machine imports every package module, so the option exists everywhere, but
the module does nothing until a composition sets
`exa-atow.pkgs.mpi-calculator.enable = true`.

Add the directory to `pkgs/modules.nix`:

```nix
imports = [
  ./openmpi.nix
  ./ddf-pipeline
  ./mpi-calculator
  ./mpi-hello
  ./openqcd
];
```

Then add a composition to `compositions.nix` that enables the app on the
frontend and on a group of two compute nodes:

```nix
mpi-calculator = topology {
  frontend.exa-atow.pkgs.mpi-calculator.enable = true;
  computeGroups.compute = {
    count = 2;
    node.exa-atow.pkgs.mpi-calculator.enable = true;
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
    node.exa-atow.pkgs = {
      mpi-hello.enable = true;
      openqcd.enable = true;
    };
  };
  compute = {
    count = 1;
    node.exa-atow.pkgs.openqcd.enable = true;
  };
};
```

Users can target compatible nodes with `srun --constraint=openqcd ...` or an
exact node with `srun --nodelist=mixed1 ...`. Multi-node jobs require enough
nodes that share the selected feature.

`just check` now passes, and the composition runs only the shared readiness
checks. The next chapter gives it a real test.

Continue with [Test it through SLURM and NXC](slurm-and-nxc.md).
