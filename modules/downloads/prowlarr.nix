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
    # (#203), which now uses the same modules/persistence.nix aspect as
    # thor. That aspect already bind-mounts the whole "/var/lib/private"
    # tree (its DynamicUser comment explains why), so
    # /var/lib/private/prowlarr survives restarts the same way it would on
    # thor - no per-service directive needed here.
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
    host = inputs.self.settings.hosts.mimir.address;
  };
}
