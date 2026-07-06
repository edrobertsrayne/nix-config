{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
in {
  flake.modules.nixos.media = {config, ...}: let
    cfg = config.services.bazarr;
    url = "bazarr.${server.domain}";
  in {
    users.users.${cfg.user}.extraGroups = ["tank"];
    systemd.services.bazarr.serviceConfig.UMask = "0002";
    services = {
      bazarr = {
        enable = true;
        listenPort = ports.media.bazarr;
        dataDir = "/srv/bazarr";
      };
      nginx.virtualHosts."${url}" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${builtins.toString cfg.listenPort}";
          proxyWebsockets = true;
        };
      };
    };

    homepage.services."Media" = [
      {
        Bazarr = {
          href = "https://${url}";
          description = "Subtitle manager";
          icon = "bazarr.png";
          siteMonitor = "http://127.0.0.1:${toString ports.media.bazarr}";
        };
      }
    ];
  };
}
