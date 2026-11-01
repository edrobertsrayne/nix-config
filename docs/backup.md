# Backups

thor backs up its own state and the Immich library to restic repositories on
its other disks. It also runs a restic REST server that odin and freyja back up
to. Everything is local to thor for now. An off-site copy is designed for (see
[Off-site, later](#off-site-later)) but not built yet (#169).

Code: `modules/restic.nix` (thor's jobs and metrics) and
`modules/restic-server.nix` (the REST server and client pruning).

## Layout

| Repo | Source | Repo path | Disk |
|---|---|---|---|
| `thor-state` | `/srv` and `/persist`, plus a `pg_dumpall` | `/mnt/storage/restic/thor-state` | HDD (mergerfs) |
| `thor-state-ssd` | a `restic copy` of `thor-state` | `/mnt/ssd/restic/thor-state` | SSD |
| `thor-immich` | `/mnt/ssd/immich` | `/mnt/storage/restic/thor-immich` | HDD (mergerfs) |
| `odin`, `freyja` | the laptops, over the tailnet | `/mnt/storage/restic/clients/<host>` | HDD (mergerfs) |

Every repo is on a different physical disk from its source. thor-state has
two backups, so it still has one after the HDD or the SSD fails. Immich and the
laptops have one backup each. The off-site copy is meant to be their second.

### What thor-state includes

Everything under `/srv` and `/persist`, except:

- `/srv/docker`: rebuilt from images.
- `/srv/loki`, `/srv/jellyfin/log`, `/persist/var/log`,
  `/persist/var/lib/prometheus`: logs and metrics, not state.
- `/persist/var/lib/postgresql`: the live database files. The dump at
  `/srv/backup/postgresql/all.sql` covers them.
- `/persist/var/lib/private/ollama`: models, 24G, re-downloadable.

`/persist` holds the SSH host keys (`/persist/etc/ssh`), so a restore also gets
back the key that decrypts the agenix secrets.

thor-immich skips `thumbs/` and `encoded-video/`. Immich regenerates both from
the originals. Immich's own nightly database dumps in `backups/` are included.

## Schedule and retention

| Time | Job |
|---|---|
| 03:00 (+ up to 30 min) | `restic-backups-thor-state`, then `restic-backups-thor-state-ssd` on success |
| 03:00 (+ up to 30 min) | `restic-backups-thor-immich` |
| 05:00 (+ up to 30 min) | `restic-backups-clients-{odin,freyja}`: prune only |
| hourly | `restic-metrics` |

Every repo keeps 7 daily, 4 weekly and 6 monthly snapshots. Each job then runs
`restic check --read-data-subset=5%`, so each night reads back a different part
of the backup data.

### How thor-state gets a consistent copy

The prepare step does these things, in this sequence:

1. It runs `postgresqlBackup.service` and waits for the dump.
2. It takes one atomic ZFS snapshot, `zroot/srv@restic zroot/persist@restic`.
3. It backs up from `/srv/.zfs/snapshot/restic` and
   `/persist/.zfs/snapshot/restic`.

The cleanup step destroys the `@restic` snapshots, also after a failure. Every
file comes from the same instant, so the SQLite databases (vaultwarden, ntfy,
uptime-kuma, the \*arr apps) are crash-consistent.

## The repo password

One password unlocks every repo: `secrets/restic-password.age`.

> **Keep a copy of this password off thor.** agenix can decrypt it only with
> keys that live on thor, and Vaultwarden also runs on thor. If thor is lost,
> the backups are unreadable without the password. Write it down, or store it
> in a password manager on another machine:
>
> ```sh
> cd secrets && nix run github:ryantm/agenix -- -d restic-password.age
> ```

The laptops use the same repo password. Each laptop also has its own REST
server login, in `secrets/restic-rest-users.age` (`user:password` lines). At
boot, `restic-rest-server-htpasswd.service` turns that file into a bcrypt
htpasswd.

## Restoring

Every job has a wrapper with its environment already set:
`restic-thor-state`, `restic-thor-state-ssd`, `restic-thor-immich`.

```sh
sudo restic-thor-state snapshots
sudo restic-thor-state ls latest | grep vaultwarden
sudo restic-thor-state restore latest --target /tmp/restore \
  --include /srv/.zfs/snapshot/restic/grafana
```

Paths in thor-state start with `/srv/.zfs/snapshot/restic/` or
`/persist/.zfs/snapshot/restic/`, because that is where the backup reads from.
After a restore, copy the files from under `/tmp/restore` back to their real
place, with the service stopped.

For a recent mistake, a ZFS snapshot is faster
([storage.md](storage.md#getting-a-file-back)). Use restic when the pool or the
SSD is gone.

### Postgres

The dump holds every database (immich, blocky):

```sh
sudo restic-thor-state restore latest --target /tmp/restore \
  --include /srv/.zfs/snapshot/restic/backup/postgresql
sudo -u postgres psql -f /tmp/restore/srv/.zfs/snapshot/restic/backup/postgresql/all.sql postgres
```

### If the backup disk failed

If the HDD fails, `thor-state-ssd` has the same snapshots. Use
`restic-thor-state-ssd` in the commands above. After you replace the disk, the
next run of `thor-state` makes a new repo. Its snapshots start again from that
day.

### Test restore (monthly)

1. Restore `/persist/.zfs/snapshot/restic/var/lib/vaultwarden` from thor-state
   to `/tmp/restore`.
2. Run `sqlite3 <file> 'PRAGMA integrity_check'`. The result must be `ok`.
3. Restore one Immich original and `cmp` it with the file in `/mnt/ssd/immich`.
4. Check that the SSD copy is current. `restic copy` gives each copied
   snapshot a new ID and records the source ID as `original`:

   ```sh
   sudo restic-thor-state snapshots --latest 1 --json | jq -r '.[].short_id'
   sudo restic-thor-state-ssd snapshots --latest 1 --json | jq -r '.[].original[0:8]'
   ```

   The two IDs must match.
5. Check that both datasets made it in. Each count must be well above zero:

   ```sh
   sudo restic-thor-state ls latest | grep -c '^/persist/'
   sudo restic-thor-state ls latest | grep -c '^/srv/'
   ```

## Laptop backups (odin, freyja)

The REST server is on `thor:8010`. It is reachable only over the tailnet, and
it runs with two settings:

- **`--private-repos`**: a login can reach only `/<user>/`.
- **`--append-only`**: a client can add snapshots, but it cannot delete or
  change them. A compromised laptop cannot erase its own history. Because of
  this, thor runs `forget --prune` on these repos locally, at 05:00.

### Set up a laptop (Omarchy / Arch)

Do these steps as your normal user on the laptop. The examples use odin.

1. Install restic:

   ```sh
   sudo pacman -S restic
   ```

2. On thor, get the laptop's login and the repo password:

   ```sh
   cd ~/config/secrets
   nix run github:ryantm/agenix -- -d restic-rest-users.age   # the odin: line
   nix run github:ryantm/agenix -- -d restic-password.age
   ```

3. On the laptop, put the settings in `~/.config/restic/`, readable only by you:

   ```sh
   mkdir -p ~/.config/restic && chmod 700 ~/.config/restic
   cat > ~/.config/restic/env <<'EOF'
   RESTIC_REPOSITORY=rest:http://thor:8010/odin/
   RESTIC_REST_USERNAME=odin
   RESTIC_REST_PASSWORD=<odin's password from restic-rest-users>
   EOF
   printf '%s\n' '<repo password>' > ~/.config/restic/password
   chmod 600 ~/.config/restic/env ~/.config/restic/password
   ```

4. Make an excludes file, `~/.config/restic/excludes`:

   ```text
   /home/*/.cache
   /home/*/.local/share/Trash
   /home/*/.local/share/Steam
   /home/*/.var/app/*/cache
   /home/*/Downloads
   node_modules
   .venv
   target
   ```

5. Create the repo, once:

   ```sh
   set -a; . ~/.config/restic/env; set +a
   RESTIC_PASSWORD_FILE=~/.config/restic/password restic init
   ```

6. Add a systemd **user** service and timer.

   `~/.config/systemd/user/restic-backup.service`:

   ```ini
   [Unit]
   Description=restic backup to thor
   Wants=network-online.target
   After=network-online.target

   [Service]
   Type=oneshot
   EnvironmentFile=%h/.config/restic/env
   Environment=RESTIC_PASSWORD_FILE=%h/.config/restic/password
   ExecStart=/usr/bin/restic backup --exclude-caches \
     --exclude-file=%h/.config/restic/excludes %h
   ```

   `~/.config/systemd/user/restic-backup.timer`:

   ```ini
   [Unit]
   Description=Daily restic backup to thor

   [Timer]
   OnCalendar=daily
   RandomizedDelaySec=1h
   Persistent=true

   [Install]
   WantedBy=timers.target
   ```

   Then enable it, and keep it running when you are logged out:

   ```sh
   systemctl --user daemon-reload
   systemctl --user enable --now restic-backup.timer
   loginctl enable-linger "$USER"
   systemctl --user start restic-backup.service   # first run now
   ```

7. Do **not** run `forget` or `prune` from the laptop. The server refuses them,
   and thor prunes these repos.

The repo appears on thor with the first backup. `restic-metrics` then picks it
up within the hour, and `ResticClientBackupStale` warns after 7 days without a
new snapshot.

To add another machine, add a `name:password` line to
`restic-rest-users.age` and the name to `clients` in
`modules/restic-server.nix`, then deploy.

## Monitoring

`restic-metrics` writes `restic.prom` to the node-exporter textfile directory:

- `restic_last_snapshot_timestamp_seconds{repo}`
- `restic_snapshot_count{repo}`
- `restic_repo_readable{repo}`

The alerts are in the `backup-health` group in `modules/alert-rules.nix`. See
[monitoring.md](monitoring.md). A failed backup, copy, prune or check unit
triggers `SystemdUnitFailed`.

## mergerfs and a second HDD

The HDD repos are on `/mnt/storage`, so a disk added to the pool also gives them
space. Before you add a disk, check the create policy:

```sh
getfattr -n user.mergerfs.category.create /mnt/storage/.mergerfs
```

Some policies keep new files on the disk that already holds their directory
(`ep*` policies). Others spread a repo's pack files across disks. If the files
spread, one failed disk damages every repo on the pool. Then a restore depends
on `thor-state-ssd` (for thor-state) and on the off-site copy.

## Off-site, later

The plan from #169 is a Hetzner Storage Box over `sftp:`, with thor's repos
only:

```sh
restic -r sftp:<box>:thor-state init \
  --from-repo /mnt/storage/restic/thor-state --copy-chunker-params
restic -r sftp:<box>:thor-state copy --from-repo /mnt/storage/restic/thor-state
```

Do the same for `thor-immich`. A job like `thor-state-ssd` (a prepare step that
runs `restic copy`, with the shared prune and check settings) can run it on a
timer. Matching chunker params let the copy deduplicate as well as the source
repo does.
