{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
in {
  flake.modules.nixos.karakeep = {config, ...}: let
    url = "keep.${server.domain}";
    port = ports.karakeep;
  in {
    age.secrets.karakeep.file = ../secrets/karakeep.age;
    services = {
      karakeep = {
        enable = true;
        extraEnvironment = {
          PORT = "${toString port}";
          NEXTAUTH_URL = "https://${url}";
        };
        environmentFile = config.age.secrets.karakeep.path;
      };
      nginx.virtualHosts."${url}" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString port}";
          proxyWebsockets = true;
        };
      };
    };

    homepage.services."Productivity" = [
      {
        Karakeep = {
          href = "https://${url}";
          description = "Bookmark manager";
          icon = "karakeep.png";
          siteMonitor = "http://127.0.0.1:${toString port}";
        };
      }
    ];
  };
}
