{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.radarr = inputs.self.lib.mkArr {
    service = "radarr";
    port = ports.media.radarr;
    secret = ../../secrets/radarr-apikey.age;
  };

  # Runs on mimir (#203); this vhost is what actually makes it reachable -
  # it must be imported by thor, the only host with nginx/cloudflared.
  flake.modules.nixos.radarr-proxy = inputs.self.lib.mkProxiedService {
    name = "Radarr";
    subdomain = "radarr";
    port = ports.media.radarr;
    description = "Movie manager";
    icon = "radarr.png";
    group = "Media";
    probePath = "/ping";
    host = inputs.self.settings.mimir.tailscaleHost;
  };
}
