# ebuffer : server module
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.ebuffer;

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
    "${pythonEnv}/lib/ebuffer"
    "--port"
    (toString cfg.port)
    "ebuffer.server:app"
    "--host"
    cfg.host
  ];

in
{
  options.services.ebuffer = {
    enable = lib.mkEnableOption "ebuffer API server";
    package = lib.mkPackageOption pkgs "ebuffer" { };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Bind host for uvicorn.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "ebuffer";
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

    # database
  };

  config = lib.mkIf cfg.enable {
    systemd.services.ebuffer = {
      description = "Ebuffer API Server";
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
