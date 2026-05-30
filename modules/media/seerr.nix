{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
in {
  flake.modules.nixos.media = {
    services.seerr.enable = true;

    services.nginx.virtualHosts = {
      "jellyseerr.${server.domain}" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString ports.media.seerr}";
          proxyWebsockets = true;
        };
      };
      "seerr.${server.domain}" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString ports.media.seerr}";
          proxyWebsockets = true;
        };
      };
    };

    homepage.services."Media" = [
      {
        Jellyseerr = {
          href = "https://seerr.${server.domain}";
          description = "Request manager";
          icon = "jellyseerr.png";
          siteMonitor = "http://127.0.0.1:${toString ports.media.seerr}";
        };
      }
    ];
  };
}
