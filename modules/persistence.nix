_: {
  flake.modules.nixos.persistence = {
    # ASSUMPTION: any host importing this aspect, or `common` (whose `tailscale`
    # aspect declares persistence), provides a /persist dataset. Declarations
    # are unconditional, and thor, mimir and njord are all impermanent.
    #
    # /etc/machine-id stays here because every importer persists
    # /var/log/journal, whose subdirectory is named after machine-id; an
    # unstable id would orphan those journals. microvm.nix writes machine-id
    # from `microvm.machineId` by default, which collides with the bind-mount,
    # so guests set it to null (modules/microvm-guest.nix); a non-microvm
    # importer would need its own guard.
    #
    # Root is wiped on boot, so /etc/ssh is empty when agenix runs (long before
    # impermanence restores it). /persist is mounted in stage 1 (neededForBoot),
    # so read the identity from there. ed25519 only: every secrets.nix entry is
    # keyed to that key, and a one-entry list makes a missing identity fail
    # loud.
    age.identityPaths = ["/persist/etc/ssh/ssh_host_ed25519_key"];

    environment.persistence."/persist" = {
      hideMounts = true;
      directories = [
        "/var/lib/nixos" # uid/gid allocation map — MUST persist
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
        # earlier in activation than impermanence restores it.
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
      ];
    };
  };
}
