{
  # Each key becomes an NXC composition name. A value may be one module or a
  # list; every selected module is installed on the frontend and compute roles.
  mpi-hello = ./mpi-hello.nix;
  openqcd = ./openqcd.nix;
  multi-software-composition = [
    ./mpi-hello.nix
    ./openqcd.nix
  ];
}
