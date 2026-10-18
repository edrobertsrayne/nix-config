_: {
  flake.modules.nixos.zfs = {
    boot.zfs.forceImportRoot = false;

    # OpenZFS lets the ARC grow to nearly all of RAM by default, and Linux
    # does not count it in MemAvailable, so the kernel swapped guest pages
    # instead of waiting for the ARC to shrink (#221: ARC sat at ~9.7 GiB on
    # a 31 GiB host). 4 GiB is plenty: zroot holds only /nix, /srv, /home and
    # the VM images, the hit rate stayed at 99.8%, and media lives on ext4,
    # which uses the normal page cache. Apply without a reboot with
    # `echo 4294967296 | sudo tee /sys/module/zfs/parameters/zfs_arc_max`.
    boot.kernelParams = ["zfs.zfs_arc_max=4294967296"];

    services.zfs.autoSnapshot = {
      enable = true;
      frequent = 4; # 15-min, 1 hour of cover
      hourly = 24;
      daily = 7;
      weekly = 4;
      monthly = 3;
    };

    services.zfs.autoScrub = {
      enable = true;
      interval = "weekly";
    };
  };
}
