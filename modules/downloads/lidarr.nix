{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.lidarr = inputs.self.lib.mkArr {
    service = "lidarr";
    port = ports.media.lidarr;
    secret = ../../secrets/lidarr-apikey.age;
  };

  # Runs on mimir (#203); this vhost is what actually makes it reachable -
  # it must be imported by thor, the only host with nginx/cloudflared.
  flake.modules.nixos.lidarr-proxy = inputs.self.lib.mkProxiedService {
    name = "Lidarr";
    subdomain = "lidarr";
    port = ports.media.lidarr;
    description = "Music manager";
    icon = "lidarr.png";
    group = "Media";
    probePath = "/ping";
    host = inputs.self.settings.mimir.address;
  };
}
