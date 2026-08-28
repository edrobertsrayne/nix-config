{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.prowlarr = {
    imports = [
      (inputs.self.lib.mkArr {
        service = "prowlarr";
        port = ports.media.prowlarr;
        secret = ../../secrets/prowlarr-apikey.age;
        dynamicUser = true;
        umask = false;

        dataDir = null;
      })
    ];

    services.flaresolverr.enable = true;
  };

  flake.modules.nixos.prowlarr-proxy = inputs.self.lib.mkProxiedService {
    name = "Prowlarr";
    subdomain = "prowlarr";
    port = ports.media.prowlarr;
    description = "Indexer manager";
    icon = "prowlarr.png";
    group = "Media";
    probePath = "/ping";
    host = inputs.self.settings.hosts.mimir.tailnetName;
  };
}
