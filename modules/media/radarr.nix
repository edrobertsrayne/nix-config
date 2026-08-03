{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.radarr = inputs.self.lib.mkArr {
    service = "radarr";
    name = "Radarr";
    port = ports.media.radarr;
    description = "Movie manager";
    icon = "radarr.png";
    secret = ../../secrets/radarr-apikey.age;
  };
}
