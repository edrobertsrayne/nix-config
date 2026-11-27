{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.sonarr = inputs.self.lib.mkArr {
    service = "sonarr";
    port = ports.media.sonarr;
    secret = ../../secrets/sonarr-apikey.age;
  };

  flake.modules.nixos.sonarr-proxy = inputs.self.lib.mkProxiedService {
    name = "Sonarr";
    subdomain = "sonarr";
    port = ports.media.sonarr;
    description = "TV series manager";
    icon = "sonarr.png";
    group = "Media";
    probePath = "/ping";
    host = inputs.self.settings.hosts.mimir.tailnetName;
  };
}
