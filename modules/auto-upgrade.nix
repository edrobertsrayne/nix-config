_: {
  # Opt-in, not part of `common`: a microvm guest has no nix-daemon and a
  # read-only /nix/store, so nixos-upgrade cannot run there. thor deploys the
  # guests with its own upgrade.
  #
  # Tracking `main` unattended is deliberate: commits reach main only after
  # `nixos-rebuild test` on thor. Recovery is layered: kept systemd-boot
  # generations roll back config (allowReboot falls back if one won't boot), and
  # auto-snapshotted /srv + /persist roll back data.
  #
  # `operation = "boot"`, not `switch`: a new environment.persistence line
  # applied live at 04:00 would bind-mount an empty /persist dir over a running
  # service's real data. Userspace updates stay staged until something reboots
  # thor; allowReboot still fires on a kernel bump.
  flake.modules.nixos.auto-upgrade = {
    system.autoUpgrade = {
      enable = true;
      operation = "boot";
      flake = "github:edrobertsrayne/nix-config";
      flags = [];
      dates = "04:00";
      allowReboot = true;
    };
  };
}
