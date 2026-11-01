{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  # Receives backups from odin and freyja (Omarchy, not managed here; see the
  # client runbook in docs/backup.md). Tailnet-only: no openFirewall, and
  # tailscale0 is the only trusted interface (tailscale.nix).
  flake.modules.nixos.restic-server = {
    config,
    lib,
    pkgs,
    ...
  }: let
    dataDir = "/mnt/storage/restic/clients";
    clients = ["odin" "freyja"];
    htpasswd = "/run/restic-rest-server-htpasswd";
  in {
    imports = [inputs.self.modules.nixos.restic];

    # "user:password" per line. Kept in plaintext rather than as bcrypt hashes
    # so `agenix -d` can hand a client its password again.
    age.secrets.restic-rest-users.file = ../secrets/restic-rest-users.age;

    services.restic.server = {
      enable = true;
      inherit dataDir;
      listenAddress = toString ports.resticServer;
      # Each login sees only /<user>/, and can add snapshots but never delete
      # them: a compromised laptop can't erase its own history. thor prunes
      # these repos locally instead (below).
      privateRepos = true;
      appendOnly = true;
      htpasswd-file = htpasswd;
    };

    backup.restic.repos = lib.genAttrs clients (c: "${dataDir}/${c}");

    # Forget/prune only: no paths, so the module skips the backup step. Runs
    # as restic so pruned repos stay owned by the rest-server's user.
    services.restic.backups = lib.listToAttrs (map (c:
      lib.nameValuePair "clients-${c}" (config.backup.restic.jobDefaults
        // {
          repository = "${dataDir}/${c}";
          user = "restic";
          # After thor's own jobs, so they don't share the disk.
          timerConfig = config.backup.restic.jobDefaults.timerConfig // {OnCalendar = "05:00";};
        }))
    clients);

    systemd = {
      services =
        {
          # tmpfiles below must run on the mount, not under it.
          systemd-tmpfiles-setup.after = ["mnt-storage.mount"];

          # The sandbox's ReadWritePaths needs dataDir to exist.
          restic-rest-server = {
            unitConfig.RequiresMountsFor = [dataDir];
            requires = ["restic-rest-server-htpasswd.service"];
            after = ["restic-rest-server-htpasswd.service"];
          };

          restic-rest-server-htpasswd = {
            description = "Build the restic REST server htpasswd from the agenix users file";
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              UMask = "0077";
            };
            script = ''
              tmp=$(mktemp)
              trap 'rm -f "$tmp"' EXIT
              while IFS=: read -r user pass; do
                [ -n "$user" ] || continue
                printf '%s' "$pass" | ${pkgs.apacheHttpd}/bin/htpasswd -iB "$tmp" "$user"
              done < ${config.age.secrets.restic-rest-users.path}
              install -m 0400 -o restic -g restic "$tmp" ${htpasswd}
            '';
          };
        }
        # A client's repo appears with its first backup; until then there is
        # nothing to prune.
        // lib.genAttrs (map (c: "restic-backups-clients-${c}") clients) (name: {
          unitConfig = {
            RequiresMountsFor = [dataDir];
            ConditionPathExists = "${dataDir}/${lib.removePrefix "restic-backups-clients-" name}/config";
          };
        });

      tmpfiles.rules = ["d ${dataDir} 0750 restic restic -"];
    };
  };
}
