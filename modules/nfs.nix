_: {
  flake.modules.nixos.nfs = {
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
      # Deliberate: NFS is tailnet-only (100.64.0.0/10); LAN-only devices (Sonos
      # etc.) fall back to the guest-read-only Samba shares for media/music. The
      # tailnet has one user, so the whole CGNAT range is "my devices", and
      # pinning peer IPs would break on every new device. `insecure` (client
      # ports >1023) is kept: privileged-port checks add nothing here, and
      # dropping it risks breaking a client that uses a high source port.
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
