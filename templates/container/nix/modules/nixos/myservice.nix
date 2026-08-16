{ flake, inputs }:
{
  config,
  lib,
  pkgs,
  perSystem,
  ...
}:
let
  cfg = config.services.myservice;
  tomlFormat = pkgs.formats.toml { };

  # Merge structured options into the freeform settings.
  # Tweak this to match the shape your service expects in its config file.
  effectiveSettings = lib.recursiveUpdate cfg.settings {
    server = {
      inherit (cfg) host port;
    };
  };

  configFile = tomlFormat.generate "myservice.toml" effectiveSettings;
in
{
  options.services.myservice = {
    enable = lib.mkEnableOption "myservice";

    package = lib.mkOption {
      type = lib.types.package;
      inherit (perSystem.self) default;
      defaultText = lib.literalExpression "perSystem.self.default";
      description = "The myservice package to use.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "The address to bind the server to.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "The port to listen on.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the firewall for the service port.";
    };

    command = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.package}/bin/myservice";
      defaultText = lib.literalExpression ''"\''${cfg.package}/bin/myservice"'';
      description = "The executable to run as the service entrypoint.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "serve"
        "--config"
        "${configFile}"
      ];
      defaultText = lib.literalExpression ''[ "serve" "--config" "\''${configFile}" ]'';
      description = ''
        Arguments passed to the service binary. The default assumes a
        `serve --config <file>` interface; override to match your CLI.
      '';
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        LOG_LEVEL = "info";
      };
      description = "Extra environment variables for the systemd unit.";
    };

    settings = lib.mkOption {
      inherit (tomlFormat) type;
      default = { };
      description = ''
        Additional settings to include in myservice.toml.
        These are merged with the structured options above.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    systemd.services.myservice = {
      description = "myservice";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      inherit (cfg) environment;

      serviceConfig = {
        Type = "simple";
        ExecStart = lib.escapeShellArgs ([ cfg.command ] ++ cfg.extraArgs);
        Restart = "on-failure";
        RestartSec = 5;

        # Hardening
        DynamicUser = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        # Add read-only data paths here, e.g.:
        #   ReadOnlyPaths = [ "/var/lib/myservice-data" ];
        NoNewPrivileges = true;
        PrivateTmp = true;
      };
    };
  };
}
