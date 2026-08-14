{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.sonarr = inputs.self.lib.mkArr {
    service = "sonarr";
    port = ports.media.sonarr;
    secret = ../../secrets/sonarr-apikey.age;
  };

  # See docs/deploying.md, "Same-host vs. cross-host services", for why this module exists.
  flake.modules.nixos.sonarr-proxy = inputs.self.lib.mkProxiedService {
    name = "Sonarr";
    subdomain = "sonarr";
    port = ports.media.sonarr;
    description = "TV series manager";
    icon = "sonarr.png";
    group = "Media";
    # /ping is the only *arr endpoint reachable without an API key. It checks
    # database access, rather than only answering. A Servarr app whose database
    # cannot open still serves its UI on /, but returns 500 here.
    probePath = "/ping";
    host = inputs.self.settings.hosts.mimir.address;
  };
}
