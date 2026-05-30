{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  url = "vault.${server.domain}";
  port = ports.vaultwarden;
in {
  flake.modules.nixos.vaultwarden = {
    services = {
      vaultwarden = {
        enable = true;
        config = {
          ROCKET_PORT = port;
          DOMAIN = "https://${url}";
          SIGNUPS_ALLOWED = false;
          LOG_LEVEL = "warn";
          EXTENDED_LOGGING = true;
        };
      };
      nginx.virtualHosts."${url}" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString port}";
          proxyWebsockets = true;
        };
      };
    };

    homepage.services."Tools" = [
      {
        Vaultwarden = {
          href = "https://${url}";
          description = "Password manager";
          icon = "vaultwarden.png";
          siteMonitor = "http://127.0.0.1:${toString port}";
        };
      }
    ];
  };
}
