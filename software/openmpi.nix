{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.openmpi ];
  environment.variables = {
    OMPI_MCA_pml = "ob1";
    OMPI_MCA_btl = "tcp,self";
  };
}
