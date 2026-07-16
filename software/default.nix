{
  # The key becomes the NXC composition name. Each module is installed on the
  # frontend and compute roles only when its composition is selected.
  mpi-hello = ./mpi-hello.nix;
  openqcd = ./openqcd.nix;
}
