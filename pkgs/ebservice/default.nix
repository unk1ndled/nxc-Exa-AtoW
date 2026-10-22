# ebservice : client module
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.ebservice;

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.uvicorn
    ps.uvloop
    ps.httptools
    cfg.package
  ]);

  execStart = lib.concatStringsSep " " [
    "${pythonEnv}/bin/uvicorn"
    "--log-config=./log_conf.yaml"
    "--app-dir"
    "${pythonEnv}/lib/ebservice"
    "--port"
    (toString cfg.port)
    "ebservice.server:app"
    "--host"
    cfg.host
  ];

in
{
  options.services.ebservice = {
    enable = lib.mkEnableOption "ebservice API server";

    package = lib.mkPackageOption pkgs "ebservice" { };

    helpers = lib.mkPackageOption pkgs "ebhelpers" { };

    ebserverhost = lib.mkOption {
      type = lib.types.str;
      default = "docker-ebuffer-server-1";
    };

    ebserverPort = lib.mkOption {
      type = lib.types.port;
      default = 8000;
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8001;
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Bind host for uvicorn.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "ebservice";
      description = ''
        Subdirectory under /var/lib used for the SQLite database.
        systemd StateDirectory value do not use an absolute path.
      '';
    };

    configDir = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a folder to copy into the service working directory.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.helpers ];
    environment.variables = {
      EBAPI_PORT = "${toString cfg.ebserverPort}";
      EBAPI_URL = "${cfg.ebserverhost}:${toString cfg.ebserverPort}";
    };
    systemd.services.ebservice = {
      description = "Ebservice API Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      preStart = lib.optionalString (cfg.configDir != null) ''
        echo "Copying config files from ${cfg.configDir} without ownership metadata..."
        cp -r --no-preserve=ownership ${cfg.configDir}/* .
        chmod -R u+w .

        echo "Sqlite setup"
        mkdir -p ./data
        touch ./data/eb_database.db
      '';

      serviceConfig = {
        ExecStart = execStart;
        StateDirectory = cfg.dataDir;
        WorkingDirectory = "/var/lib/${cfg.dataDir}";
        DynamicUser = true;
        RestartSec = "5s";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };
  };
}
