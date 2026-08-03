{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.prowlarr = {
    imports = [
      (inputs.self.lib.mkArr {
        service = "prowlarr";
        name = "Prowlarr";
        port = ports.media.prowlarr;
        description = "Indexer manager";
        icon = "prowlarr.png";
        secret = ../../secrets/prowlarr-apikey.age;
        dynamicUser = true;
        umask = false;
      })
    ];

    services.flaresolverr.enable = true;
  };
}
