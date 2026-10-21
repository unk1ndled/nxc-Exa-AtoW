# Every app module. Each app is off until a composition enables it with
# `exa-atow.apps.<name>.enable = true`.
{
  imports = [
    ./openmpi.nix
    ./mpi-hello
    ./openqcd
  ];
}
