_: {
  flake.modules.nixos.zfs = {lib, ...}: {
    boot.zfs.forceImportRoot = false;

    # Reduce ZFS monthly snapshots (default is 12)
    services.zfs.autoSnapshot.monthly = lib.mkDefault 1;
  };
}
