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
        # Loopback only: reached via nginx (cloudflared -> Access-gated, or
        # the tailnet). The firewall doesn't open this port today, so this
        # is defence-in-depth - a firewall regression can't silently
        # re-expose it (same reasoning as transmission.nix's rpc-bind).
        bind_address = "127.0.0.1";
      };
      settings.search.formats = [
        "html"
        # json stays: n8n's SearXNG tool (searXngApi credential) consumes
        # this API for web search. Safe now that it's loopback-only behind
        # Access. csv/rss dropped - unused.
        "json"
      ];
    };
  };
}
