_: {
  flake.modules.nixos.thor = {
    config,
    lib,
    ...
  }: {
    fileSystems =
      {
        "/export/media" = {
          device = "/mnt/storage/media";
          fsType = "none";
          options = ["bind"];
        };
        "/export/downloads" = {
          device = "/mnt/ssd/downloads";
          fsType = "none";
          options = ["bind"];
        };
        "/export/backup" = {
          device = "/mnt/storage/backup";
          fsType = "none";
          options = ["bind"];
        };
      }
      // lib.optionalAttrs config.services.paperless.enable {
        "/export/paperless" = {
          device = config.services.paperless.consumptionDir;
          fsType = "none";
          options = ["bind"];
        };
      };

    services.nfs.server = {
      enable = true;
      # Deliberate, not an oversight - see #175:
      # - NFS is tailnet-only (100.64.0.0/10): the LAN subnet export was
      #   dropped, so downloads/backup/media/music over NFS only reach
      #   devices on the tailnet. LAN-only devices (Sonos etc.) fall back
      #   to the guest-read-only Samba shares in samba.nix for
      #   media/music.
      # - The tailnet has exactly one user, so the whole CGNAT range is
      #   "my devices" here, not an attack surface - pinning individual
      #   peer IPs would just break on every new device.
      # - root_squash is already the default and already active -
      #   confirmed via `/var/lib/nfs/etab`
      #   (root_squash,anonuid=65534,anongid=65534 on every export); no
      #   config was needed for the corresponding acceptance criterion.
      # - `insecure` (allows client source ports >1023) is kept: privileged-
      #   port checks add nothing on top of host/range-based trust here,
      #   and dropping it risks silently breaking a client mount that
      #   happens to use a high source port.
      exports =
        ''
          /export         100.64.0.0/10(insecure,rw,sync,no_subtree_check,crossmnt,fsid=0)
          /export/media    100.64.0.0/10(insecure,rw,sync,no_subtree_check,nohide,fsid=1)
          /export/downloads    100.64.0.0/10(insecure,rw,sync,no_subtree_check,nohide,fsid=2)
          /export/backup    100.64.0.0/10(insecure,rw,sync,no_subtree_check,nohide,fsid=3)
        ''
        # fsid=4 continues the sequence above; bump for the next export added here.
        + lib.optionalString config.services.paperless.enable ''
          /export/paperless    100.64.0.0/10(insecure,rw,sync,no_subtree_check,nohide,fsid=4)
        '';
    };

    services.rpcbind.enable = true;
    # No allowedTCPPorts/allowedUDPPorts here: tailscale0 is already a
    # trusted interface (modules/tailscale.nix), so tailnet peers reach
    # these ports without opening them on the untrusted LAN bridge too.

    environment.persistence."/persist".directories = ["/var/lib/nfs"];
  };
}
