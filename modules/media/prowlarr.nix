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
        # Not /srv/prowlarr: the upstream module fakes a custom dataDir with a
        # bind mount onto /var/lib/private/prowlarr plus a tmpfiles rule pinning
        # it to root:root. Every rebuild re-runs systemd-tmpfiles, which chowns
        # the directory away from the DynamicUser and locks the running service
        # out of its own databases (#194). The default generates neither.
        dataDir = null;
      })
    ];

    services.flaresolverr.enable = true;

    # No environment.persistence directive here: prowlarr runs on mimir
    # (#203), which is a plain persistent root, not impermanent - mimir.nix
    # forces environment.persistence."/persist".enable = false, so
    # /var/lib/private/prowlarr already survives restarts by virtue of
    # living on mimir's own persistent /var volume. This used to declare a
    # "/persist" directory - leftover from before the move, and actively
    # wrong on mimir (there is no /persist dataset there).
  };

  # Runs on mimir (#203); this vhost is what actually makes it reachable -
  # it must be imported by thor, the only host with nginx/cloudflared.
  flake.modules.nixos.prowlarr-proxy = inputs.self.lib.mkProxiedService {
    name = "Prowlarr";
    subdomain = "prowlarr";
    port = ports.media.prowlarr;
    description = "Indexer manager";
    icon = "prowlarr.png";
    group = "Media";
    probePath = "/ping";
    host = inputs.self.settings.mimir.tailscaleHost;
  };
}
