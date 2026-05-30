{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  url = "ntfy.${server.domain}";
  port = ports.ntfy;
in {
  flake.modules.nixos.ntfy = {
    services.ntfy-sh = {
      enable = true;
      settings = {
        base-url = "https://${url}";
        listen-http = ":${toString port}";
        behind-proxy = true;
      };
    };

    services.nginx.virtualHosts."${url}" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString port}";
        proxyWebsockets = true;
      };
    };

    homepage.services."Tools" = [
      {
        Ntfy = {
          href = "https://${url}";
          description = "Push notifications";
          icon = "ntfy.png";
          siteMonitor = "http://127.0.0.1:${toString port}";
        };
      }
    ];
  };
}
