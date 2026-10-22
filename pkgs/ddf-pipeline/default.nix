{ config, lib, pkgs, ... }:
let
  cfg = config.exa-atow.pkgs.ddf-pipeline;
in
{
  options.exa-atow.pkgs.ddf-pipeline = {
    enable = lib.mkEnableOption "the DDFacet LOFAR imaging pipeline";
    package = lib.mkPackageOption pkgs "ddf-pipeline" { };
  };

  config = lib.mkIf cfg.enable {
    exa-atow.openmpi.enable = true;
    environment.systemPackages = [ cfg.package ];
  };
}
