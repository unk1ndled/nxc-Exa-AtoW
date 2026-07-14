{ ... }:
{
  # Each imported module is an HPC software plug-in. Add or remove modules here;
  # they are applied identically to the frontend and every compute node.
  imports = [
    ./mpi-hello.nix
  ];
}
