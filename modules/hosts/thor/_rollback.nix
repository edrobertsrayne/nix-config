{
  config,
  pkgs,
  ...
}: {
  # Wipe root to a pristine blank snapshot on every boot (systemd stage-1
  # initrd; boot.initrd.systemd.enable is already set on thor). See #163.
  #
  # Fail-open by design: nothing depends on this unit, so a failed rollback
  # boots a stale root rather than stranding a headless box in an initrd
  # emergency target it has no shell for (emergencyAccess = false). Detect
  # with `journalctl -b -u rollback-root` or a /canary file.
  boot.initrd.systemd.services.rollback-root = {
    after = ["zfs-import-zroot.service"];
    requires = ["zfs-import-zroot.service"];
    before = ["sysroot.mount"];
    wantedBy = ["initrd.target"];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    path = [pkgs.zfs];
    # Derived, not hardcoded: disko.nix is the single source of truth for the
    # root dataset name, and the dry run temporarily repoints it.
    script = "zfs rollback -r ${config.fileSystems."/".device}@blank";
  };
}
