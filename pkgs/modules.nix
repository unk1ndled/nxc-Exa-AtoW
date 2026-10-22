# Every exa-atow.pkgs module, imported on the frontend and compute nodes.
# Each is off until a composition enables it with
# `exa-atow.pkgs.<name>.enable = true`.
{
  imports = [
    ./openmpi.nix
    ./ddf-pipeline
    ./mpi-hello
    ./openqcd
  ];
}
