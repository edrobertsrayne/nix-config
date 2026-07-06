{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  apikey = "e6619670253d4b17baaa8a640a3aafed";
  service = "sonarr";
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
          server.port = ports.media.sonarr;
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

    systemd.services.${service}.serviceConfig.UMask = "0002";

    homepage.services."Media" = [
      {
        Sonarr = {
          href = "https://${service}.${server.domain}";
          description = "TV series manager";
          icon = "sonarr.png";
          siteMonitor = "http://127.0.0.1:${toString ports.media.sonarr}";
        };
      }
    ];
  };
}
