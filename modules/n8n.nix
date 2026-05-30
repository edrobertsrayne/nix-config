{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  url = "n8n.${server.domain}";
  port = ports.n8n;
in {
  flake.modules.nixos.n8n = {config, ...}: {
    age.secrets.n8n.file = ../secrets/n8n.age;

    services = {
      n8n = {
        enable = true;
        environment = {
          N8N_PORT = toString port;
          N8N_HOST = "127.0.0.1";
          WEBHOOK_URL = "https://${url}/";
          N8N_EDITOR_BASE_URL = "https://${url}/";
          GENERIC_TIMEZONE = "Europe/London";
          N8N_ENCRYPTION_KEY_FILE = config.age.secrets.n8n.path;
        };
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
        n8n = {
          href = "https://${url}";
          description = "Workflow automation";
          icon = "n8n.png";
          siteMonitor = "http://127.0.0.1:${toString port}";
        };
      }
    ];
  };
}
