_: {
  flake.modules.nixos.persistence = {
    # Persistence is a whole-configuration concern (each aspect declares its
    # own state); rollback is per-machine — see #167.
    #
    # ASSUMPTION: any host importing this aspect, or `common` (whose
    # `tailscale` aspect declares persistence), provides a /persist dataset.
    # Declarations are unconditional under the direct-merge mechanism, so
    # there is no per-host guard. thor, mimir and njord are all impermanent
    # (tmpfs root, wiped every boot) — every current importer needs this.
    # /etc/machine-id stays in this generic aspect rather than moving to a
    # thor/ZFS-specific module (#222): every importer has a tmpfs root and
    # persists /var/log/journal, whose per-machine subdirectory is named
    # after machine-id — a machine-id that isn't stable across boots would
    # orphan those persisted journals on any impermanent host, not just
    # thor. The one entry that isn't safe unconditionally is /etc/machine-id
    # itself: microvm.nix writes it from `microvm.machineId` by default,
    # which lands before this bind-mount runs and collides with it (#220).
    # Guests set `microvm.machineId = null` (modules/microvm-guest.nix) to
    # leave the path for impermanence alone; a future non-microvm host
    # importing this aspect would need its own equivalent guard.
    # Root is wiped on boot, so /etc/ssh is empty when agenix runs — it is the
    # third activation snippet, long before impermanence restores /etc/ssh.
    # /persist is mounted in stage 1 (neededForBoot), so read the identity
    # from there. This file declares that path as persisted, so the option and
    # its precondition stay together. ed25519 only: every secrets.nix entry is
    # keyed to the ed25519 thor key, so the RSA path never decrypted anything,
    # and a one-entry list makes "identity missing" fail loud rather than
    # routine. See #167.
    age.identityPaths = ["/persist/etc/ssh/ssh_host_ed25519_key"];

    environment.persistence."/persist" = {
      hideMounts = true;
      directories = [
        "/var/lib/nixos" # uid/gid allocation map — MUST persist (#163)
        "/var/lib/systemd" # random-seed, timers, linger, timesync
        "/var/log/journal" # journald Storage=auto already writes here
        {
          # systemd's mkdir_safe refuses a too-permissive /var/lib/private and
          # every DynamicUser service then fails to start. impermanence creates
          # parent directories with defaultPerms (0755 root) and chmods the live
          # path to match its /persist counterpart, so pin it explicitly.
          # Explicit entries are applied after generated parents, so this wins.
          directory = "/var/lib/private";
          user = "root";
          group = "root";
          mode = "0700";
        }
      ];
      files = [
        "/etc/machine-id"
        # sshd's host identity. agenix also reads the ed25519 key, but far
        # earlier in activation than impermanence restores it — see #167.
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
      ];
    };
  };
}
