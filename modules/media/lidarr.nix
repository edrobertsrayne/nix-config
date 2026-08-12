{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.lidarr = inputs.self.lib.mkArr {
    service = "lidarr";
    name = "Lidarr";
    port = ports.media.lidarr;
    description = "Music manager";
    icon = "lidarr.png";
    secret = ../../secrets/lidarr-apikey.age;
    host = inputs.self.settings.mimir.tailscaleHost;
  };
}
