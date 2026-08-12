{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.sonarr = inputs.self.lib.mkArr {
    service = "sonarr";
    port = ports.media.sonarr;
    secret = ../../secrets/sonarr-apikey.age;
  };

  # Runs on mimir (#203); this vhost is what actually makes it reachable -
  # it must be imported by thor, the only host with nginx/cloudflared.
  flake.modules.nixos.sonarr-proxy = inputs.self.lib.mkProxiedService {
    name = "Sonarr";
    subdomain = "sonarr";
    port = ports.media.sonarr;
    description = "TV series manager";
    icon = "sonarr.png";
    group = "Media";
    # /ping is the only *arr endpoint reachable without an API key, and it
    # checks database access rather than just answering - a Servarr app
    # whose database is unopenable keeps serving its UI on / but returns
    # 500 here.
    probePath = "/ping";
    host = inputs.self.settings.mimir.address;
  };
}
