{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  url = "search.${server.domain}";
  port = ports.searxng;
in {
  flake.modules.nixos.searxng = {config, ...}: {
    age.secrets.searxng.file = ../secrets/searxng.age;
    services = {
      searx = {
        enable = true;
        environmentFile = config.age.secrets.searxng.path;
        settings.server = {
          inherit port;
          base_url = "https://${url}";
          bind_address = "0.0.0.0";
        };
        settings.search.formats = [
          "html"
          "csv"
          "json"
          "rss"
        ];
      };
      nginx.virtualHosts."${url}" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString port}";
        };
      };
    };

    homepage.services."Tools" = [
      {
        SearXNG = {
          href = "https://${url}";
          description = "Private search engine";
          icon = "searxng.png";
          siteMonitor = "http://127.0.0.1:${toString port}";
        };
      }
    ];
  };
}
