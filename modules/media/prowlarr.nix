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
        # Not /srv/prowlarr: the upstream module fakes a custom dataDir with a
        # bind mount onto /var/lib/private/prowlarr plus a tmpfiles rule pinning
        # it to root:root. Every rebuild re-runs systemd-tmpfiles, which chowns
        # the directory away from the DynamicUser and locks the running service
        # out of its own databases (#194). The default generates neither.
        dataDir = null;
      })
    ];

    services.flaresolverr.enable = true;

    environment.persistence."/persist".directories = ["/var/lib/private/prowlarr"];
  };
}
