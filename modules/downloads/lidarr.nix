{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.lidarr = inputs.self.lib.mkArr {
    service = "lidarr";
    port = ports.media.lidarr;
    secret = ../../secrets/lidarr-apikey.age;
  };

  # See docs/deploying.md, "Same-host vs. cross-host services", for why this module exists.
  flake.modules.nixos.lidarr-proxy = inputs.self.lib.mkProxiedService {
    name = "Lidarr";
    subdomain = "lidarr";
    port = ports.media.lidarr;
    description = "Music manager";
    icon = "lidarr.png";
    group = "Media";
    probePath = "/ping";
    host = inputs.self.settings.hosts.mimir.tailnetName;
  };
}
