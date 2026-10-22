# OpenMPI over TCP, shared by the MPI packages.
{ config, lib, pkgs, ... }:
{
  options.exa-atow.openmpi.enable = lib.mkEnableOption "OpenMPI over TCP";

  config = lib.mkIf config.exa-atow.openmpi.enable {
    environment.systemPackages = [ pkgs.openmpi ];
    environment.variables = {
      OMPI_MCA_pml = "ob1";
      OMPI_MCA_btl = "tcp,self";
    };
  };
}
