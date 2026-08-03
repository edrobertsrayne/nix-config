{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.sonarr = inputs.self.lib.mkArr {
    service = "sonarr";
    name = "Sonarr";
    port = ports.media.sonarr;
    description = "TV series manager";
    icon = "sonarr.png";
    secret = ../../secrets/sonarr-apikey.age;
  };
}
