{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  apikey = "45f0ce64ed8b4d34b51908c60b7a70fc";
  service = "radarr";
in {
  flake.modules.nixos.media = {config, ...}: let
    cfg = config.services.${service};
  in {
    services = {
      ${service} = {
        enable = true;
        dataDir = "/srv/${service}";
        openFirewall = true;
        settings = {
          server.port = ports.media.radarr;
          auth = {
            method = "External";
            type = "DisabledForLocalAddresses";
            inherit apikey;
          };
        };
      };
    };

    services.nginx.virtualHosts."${service}.${server.domain}" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${builtins.toString cfg.settings.server.port}";
        proxyWebsockets = true;
      };
    };

    users.users.${cfg.user}.extraGroups = ["tank"];

    homepage.services."Media" = [
      {
        Radarr = {
          href = "https://${service}.${server.domain}";
          description = "Movie manager";
          icon = "radarr.png";
          siteMonitor = "http://127.0.0.1:${toString ports.media.radarr}";
        };
      }
    ];
  };
}
