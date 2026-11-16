_: {
  # Opt-in, not part of `common`: a microvm guest has no nix-daemon and a
  # read-only /nix/store, so nixos-upgrade cannot run there (#219). thor
  # builds and deploys the guests with its own upgrade.
  #
  # Tracking `main` unattended is deliberate, not an oversight: commits only
  # reach main after `nixos-rebuild test` on thor, so this pulls a config
  # already validated on the machine it deploys to — a gated release branch
  # would add ceremony without adding validation. Recovery is layered: 5 kept
  # systemd-boot generations roll back config (and allowReboot falls back if
  # a generation won't boot), and auto-snapshotted /srv + /persist (#163)
  # roll back data. Same trade as floating container tags (#181): personal
  # server, stay current without manual bumps. See #178.
  # `operation = "boot"` (not the default `switch`, #167 commit 4): a
  # future commit adding an environment.persistence line would otherwise
  # apply live at 04:00, bind-mounting an empty /persist dir over a
  # running service's real data, which then vanishes at the next wipe.
  # Config-only/userspace updates now sit staged until something reboots
  # thor; allowReboot still fires unattended on a kernel bump.
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
