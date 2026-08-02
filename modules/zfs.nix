_: {
  flake.modules.nixos.zfs = {
    boot.zfs.forceImportRoot = false;

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
