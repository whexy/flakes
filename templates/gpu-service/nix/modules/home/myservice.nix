{ flake, inputs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.myservice;
  tomlFormat = pkgs.formats.toml { };

  effectiveSettings = lib.recursiveUpdate cfg.settings {
    server = {
      inherit (cfg) host port;
    };
  };

  configFile = tomlFormat.generate "myservice.toml" effectiveSettings;
in
{
  options.services.myservice = {
    enable = lib.mkEnableOption "myservice (user-level)";

    package = lib.mkOption {
      type = lib.types.package;
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
      description = "Extra environment variables for the systemd user unit.";
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
    systemd.user.services.myservice = {
      Unit = {
        Description = "myservice";
        After = [ "network.target" ];
      };

      Service = {
        Type = "simple";
        Environment = lib.mapAttrsToList (k: v: "${k}=${v}") cfg.environment;
        ExecStart = lib.escapeShellArgs ([ cfg.command ] ++ cfg.extraArgs);
        Restart = "on-failure";
        RestartSec = 5;
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
