{inputs, ...}: let
  inherit (inputs.self.lib) textfileDir;
in {
  # Local backups of thor's own data (#169). Every repo sits on a different
  # physical disk from its source. thor-state also gets a second copy on the
  # SSD, so losing the HDD or the SSD still leaves one backup of the NVMe
  # state. See docs/backup.md for the layout, restores and the client runbook.
  flake.modules.nixos.restic = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.backup.restic;
    restic = lib.getExe pkgs.restic;
    zfs = "${config.boot.zfs.package}/bin/zfs";
    systemctl = "${config.systemd.package}/bin/systemctl";
    passwordFile = config.age.secrets.restic-password.path;

    stateRepo = "/mnt/storage/restic/thor-state";
    stateSsdRepo = "/mnt/ssd/restic/thor-state";
    immichRepo = "/mnt/storage/restic/thor-immich";

    # thor-state reads from one atomic snapshot of both datasets, so SQLite
    # files and the pg dump are consistent with each other and never caught
    # mid-write.
    snapName = "restic";
    datasets = ["zroot/srv" "zroot/persist"];
    snapPath = mount: "${mount}/.zfs/snapshot/${snapName}";
    srvSnap = snapPath "/srv";
    persistSnap = snapPath "/persist";
    destroySnaps = lib.concatMapStringsSep "\n" (ds: "${zfs} destroy ${ds}@${snapName} 2>/dev/null || true") datasets;

    metrics = pkgs.writeShellScript "restic-metrics" ''
      set -uo pipefail

      out=${textfileDir}/restic.prom
      tmp=$out.tmp

      {
        echo "# HELP restic_repo_readable 1 if restic could list the repo's snapshots."
        echo "# TYPE restic_repo_readable gauge"
        echo "# HELP restic_snapshot_count Number of snapshots in the repo."
        echo "# TYPE restic_snapshot_count gauge"
        echo "# HELP restic_last_snapshot_timestamp_seconds Time of the newest snapshot in the repo."
        echo "# TYPE restic_last_snapshot_timestamp_seconds gauge"

        ${lib.concatStrings (lib.mapAttrsToList (name: path: ''
          # A client repo only exists after that machine's first backup, so a
          # missing repo publishes nothing rather than a failure.
          if [ -e ${path}/config ]; then
            if json=$(${restic} -r ${path} --password-file ${passwordFile} snapshots --json --no-lock); then
              printf 'restic_repo_readable{repo="%s"} 1\n' ${name}
              printf 'restic_snapshot_count{repo="%s"} %s\n' ${name} "$(${lib.getExe pkgs.jq} length <<<"$json")"
              latest=$(${lib.getExe pkgs.jq} -r 'map(.time) | max // empty' <<<"$json")
              if [ -n "$latest" ]; then
                printf 'restic_last_snapshot_timestamp_seconds{repo="%s"} %s\n' ${name} "$(date -d "$latest" +%s)"
              fi
            else
              printf 'restic_repo_readable{repo="%s"} 0\n' ${name}
            fi
          fi
        '')
        cfg.repos)}
      } > "$tmp"

      # node-exporter will happily read a half-written file.
      mv "$tmp" "$out"
    '';
  in {
    # Imported by restic-server as well as thor.
    key = "restic-aspect";
    imports = [inputs.self.modules.nixos.textfile-collector];

    options.backup.restic = {
      repos = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Repo paths keyed by the name used as the `repo` label in restic metrics.";
      };

      jobDefaults = lib.mkOption {
        type = lib.types.attrs;
        readOnly = true;
        description = "Settings every services.restic.backups job shares, so retention stays the same for every repo.";
      };
    };

    config = {
      age.secrets.restic-password = {
        file = ../secrets/restic-password.age;
        # The client prune jobs run as the rest-server's restic user.
        group = "restic";
        mode = "0440";
      };
      users.groups.restic = {};

      backup.restic = {
        repos = {
          thor-state = stateRepo;
          thor-state-ssd = stateSsdRepo;
          thor-immich = immichRepo;
        };

        jobDefaults = {
          inherit passwordFile;
          pruneOpts = [
            "--keep-daily 7"
            "--keep-weekly 4"
            "--keep-monthly 6"
          ];
          # Reads back a different 5% of the pack data each night, so silent
          # corruption on the backup disk surfaces within about three weeks.
          runCheck = true;
          checkOpts = ["--read-data-subset=5%"];
          timerConfig = {
            OnCalendar = "03:00";
            RandomizedDelaySec = "30m";
            Persistent = true;
          };
        };
      };

      # Written by thor-state's prepare step only; no timer of its own.
      services.postgresqlBackup = {
        enable = true;
        backupAll = true;
        # Uncompressed so restic can dedup one night's dump against the last.
        compression = "none";
        location = "/srv/backup/postgresql";
        startAt = [];
      };

      services.restic.backups = {
        thor-state =
          cfg.jobDefaults
          // {
            repository = stateRepo;
            initialize = true;
            paths = [srvSnap persistSnap];
            exclude = [
              # Rebuilt from images.
              "${srvSnap}/docker"
              # Logs and metrics, not state.
              "${srvSnap}/loki"
              "${srvSnap}/jellyfin/log"
              "${persistSnap}/var/log"
              "${persistSnap}/var/lib/prometheus"
              # Live database files; the pg_dumpall in /srv/backup covers them.
              "${persistSnap}/var/lib/postgresql"
              # Re-downloadable models, 24G.
              "${persistSnap}/var/lib/private/ollama"
            ];
            backupPrepareCommand = ''
              #!${pkgs.runtimeShell}
              set -euo pipefail
              # Blocks until the dump is written.
              ${systemctl} start postgresqlBackup.service
              ${destroySnaps}
              ${zfs} snapshot ${lib.concatMapStringsSep " " (ds: "${ds}@${snapName}") datasets}

              # .zfs/snapshot/<name> is an automount. On the first run restic
              # read /persist's before it had mounted and saved an empty
              # directory with no warning, so mount both here and refuse to
              # back up an empty one.
              for dir in ${srvSnap} ${persistSnap}; do
                for _ in 1 2 3 4 5; do
                  [ -n "$(${pkgs.coreutils}/bin/ls -A "$dir/" 2>/dev/null)" ] && continue 2
                  sleep 1
                done
                echo "$dir is empty after 5s, the snapshot did not mount" >&2
                exit 1
              done
            '';
            backupCleanupCommand = ''
              #!${pkgs.runtimeShell}
              ${destroySnaps}
            '';
          };

        # Second local copy of thor-state, run after each successful backup.
        # restic copy only moves snapshots the SSD repo lacks and never
        # rescans the source, so it is cheap.
        thor-state-ssd =
          cfg.jobDefaults
          // {
            repository = stateSsdRepo;
            timerConfig = null;
            backupPrepareCommand = ''
              #!${pkgs.runtimeShell}
              set -euo pipefail
              export RESTIC_FROM_PASSWORD_FILE=${passwordFile}
              # Matching chunker params let the copy dedup against itself.
              if [ ! -e ${stateSsdRepo}/config ]; then
                ${restic} init --from-repo ${stateRepo} --copy-chunker-params
              fi
              ${restic} copy --from-repo ${stateRepo}
            '';
          };

        # Immich regenerates thumbs and encoded-video from the originals.
        thor-immich =
          cfg.jobDefaults
          // {
            repository = immichRepo;
            initialize = true;
            paths = ["/mnt/ssd/immich"];
            exclude = [
              "/mnt/ssd/immich/thumbs"
              "/mnt/ssd/immich/encoded-video"
            ];
          };
      };

      systemd = {
        services = {
          restic-backups-thor-state = {
            unitConfig.RequiresMountsFor = ["/mnt/storage"];
            onSuccess = ["restic-backups-thor-state-ssd.service"];
          };
          restic-backups-thor-state-ssd.unitConfig.RequiresMountsFor = ["/mnt/storage" "/mnt/ssd"];
          restic-backups-thor-immich.unitConfig.RequiresMountsFor = ["/mnt/storage" "/mnt/ssd"];

          restic-metrics = {
            description = "Publish restic snapshot freshness as node-exporter textfile metrics";
            unitConfig.RequiresMountsFor = ["/mnt/storage" "/mnt/ssd"];
            environment.RESTIC_CACHE_DIR = "/var/cache/restic-metrics";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = metrics;
              CacheDirectory = "restic-metrics";
              CacheDirectoryMode = "0700";
            };
          };
        };

        timers.restic-metrics = {
          description = "Refresh the restic snapshot metrics";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnBootSec = "5m";
            OnUnitActiveSec = "1h";
          };
        };
      };
    };
  };
}
