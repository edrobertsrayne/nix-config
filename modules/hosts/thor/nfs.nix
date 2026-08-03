_: {
  flake.modules.nixos.thor = {
    fileSystems = {
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
    };

    services.nfs.server = {
      enable = true;
      # Deliberate, not an oversight - see #175:
      # - 100.64.0.0/10 (the whole CGNAT/tailnet range) is kept rw: the
      #   tailnet has exactly one user, so the range is "my devices", and
      #   pinning individual peer IPs would break on every new device
      #   without buying real isolation.
      # - 192.168.68.0/22 rw is kept so LAN machines mount without any
      #   per-host setup. `sec=sys` means a LAN host asserting UID 1000 can
      #   write `backup`; accepted here alongside the equivalent Samba
      #   decision in samba.nix (anonymous LAN read/write of a personal
      #   home server, single-occupant network).
      # - root_squash is already the default and already active -
      #   confirmed via `/var/lib/nfs/etab`
      #   (root_squash,anonuid=65534,anongid=65534 on every export); no
      #   config was needed for the corresponding acceptance criterion.
      # - `insecure` (allows client source ports >1023) is kept: privileged-
      #   port checks add nothing on top of host/range-based trust here,
      #   and dropping it risks silently breaking a client mount that
      #   happens to use a high source port.
      exports = ''
        /export         192.168.68.0/22(insecure,rw,sync,no_subtree_check,crossmnt,fsid=0) 100.64.0.0/10(insecure,rw,sync,no_subtree_check,crossmnt,fsid=0)
        /export/media    192.168.68.0/22(insecure,rw,sync,no_subtree_check,nohide,fsid=1) 100.64.0.0/10(insecure,rw,sync,no_subtree_check,nohide,fsid=1)
        /export/downloads    192.168.68.0/22(insecure,rw,sync,no_subtree_check,nohide,fsid=2) 100.64.0.0/10(insecure,rw,sync,no_subtree_check,nohide,fsid=2)
        /export/backup    192.168.68.0/22(insecure,rw,sync,no_subtree_check,nohide,fsid=3) 100.64.0.0/10(insecure,rw,sync,no_subtree_check,nohide,fsid=3)
      '';
    };

    services.rpcbind.enable = true;
    networking.firewall = {
      allowedTCPPorts = [111 2049 4000 4001 4002 20048];
      allowedUDPPorts = [111 2049 4000 4001 4002 20048];
    };
  };
}
