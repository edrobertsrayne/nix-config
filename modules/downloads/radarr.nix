{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.radarr = inputs.self.lib.mkArr {
    service = "radarr";
    port = ports.media.radarr;
    secret = ../../secrets/radarr-apikey.age;
  };

  # See docs/deploying.md, "Same-host vs. cross-host services", for why this module exists.
  flake.modules.nixos.radarr-proxy = inputs.self.lib.mkProxiedService {
    name = "Radarr";
    subdomain = "radarr";
    port = ports.media.radarr;
    description = "Movie manager";
    icon = "radarr.png";
    group = "Media";
    probePath = "/ping";
    host = inputs.self.settings.hosts.mimir.tailnetName;
  };
}
