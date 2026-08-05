_: {
  flake.modules.nixos.persistence = {
    # Persistence is a whole-configuration concern (each aspect declares its
    # own state); rollback is per-machine — see #167.
    #
    # ASSUMPTION: any host importing this aspect, or `common` (whose
    # `tailscale` aspect declares persistence), provides a /persist dataset.
    # Declarations are unconditional under the direct-merge mechanism, so
    # there is no per-host guard. Only thor is impermanent today.
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
