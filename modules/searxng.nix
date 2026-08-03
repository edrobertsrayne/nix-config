{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  url = "search.${server.domain}";
  port = ports.searxng;
in {
  flake.modules.nixos.searxng = {config, ...}: {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "SearXNG";
        subdomain = "search";
        inherit port;
        group = "Tools";
        description = "Private search engine";
        icon = "searxng.png";
        websockets = false;
      })
    ];

    age.secrets.searxng.file = ../secrets/searxng.age;
    services.searx = {
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
  };
}
