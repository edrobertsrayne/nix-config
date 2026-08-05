# Storage

Where thor's data lives, how it is shared, and — the part that matters most —
what would survive a disk failure and what would not.

The short version: **service configuration is protected, and your files are
not.** Read [What is not backed up](#what-is-not-backed-up) if you read nothing
else on this page.

## The disks

thor has four physical devices in three arrangements.

| Where | Device | Filesystem | Redundancy |
|---|---|---|---|
| `zroot` pool | 2 × 512 GB Samsung NVMe | ZFS mirror | **Survives one drive failing** |
| `/mnt/ssd` | 4 TB SSD | ext4 | None |
| `/mnt/disk1` | 8 TB HDD | ext4 | None |
| `/mnt/storage` | — | mergerfs over `/mnt/disk*` | None |

### The ZFS pool

`modules/hosts/thor/disko.nix` declares the whole layout: each NVMe gets a 1 GiB
EFI partition (`/boot` and `/boot-fallback`, so either drive can boot the
machine) and gives the rest to a mirrored pool named `zroot`.

Pool-wide settings: `ashift=12`, `compression=lz4`, `atime=off`,
`acltype=posixacl`, `xattr=sa`. The pool is **deliberately unencrypted** — the
reasoning, and why it cannot be changed without recreating the pool, is in a
comment in that file.

Five datasets, and the difference between them is the only thing standing
between you and a bad `rm`:

| Dataset | Mounted at | Snapshotted |
|---|---|---|
| `zroot/root` | `/` | no |
| `zroot/nix` | `/nix` | no |
| `zroot/srv` | `/srv` | **yes** |
| `zroot/persist` | `/persist` | **yes** |
| `zroot/libvirt` | `/var/lib/libvirt` | **yes** |

`/` and `/nix` are not snapshotted because they do not need to be — they are
rebuilt from this repo, and generations already roll them back
([deploying.md](deploying.md#undoing-a-change)).

`/persist` holds the state that survives thor's root being wiped on every boot
(#163 — the wipe itself lands in #167/#168; today the root still isn't wiped,
so this is inert). Each aspect declares its own paths directly via
`environment.persistence."/persist"` (`modules/persistence.nix` for core
system/identity state, e.g. `/var/lib/nixos`, `/etc/ssh/ssh_host_*`; every
other service aspect that has real state, e.g. `modules/vaultwarden.nix`,
`modules/tailscale.nix`, `modules/media/prowlarr.nix`, declares its own
directories alongside its service config). There's no aggregation list to read
— `nix eval .#nixosConfigurations.thor.config.environment.persistence.'"/persist"'.directories`
shows the merged result.

### mergerfs

`/mnt/storage` is not a real filesystem. mergerfs presents `/mnt/disk1` (and any
future `/mnt/disk2`, `/mnt/disk3`…) as one directory tree, choosing a disk per
file with 50 GiB kept free on each. Adding capacity means adding a disk and a
mount, not resizing anything.

It provides **no redundancy**. If `/mnt/disk1` dies, everything on it is gone;
the difference from plain ext4 is only that a second disk's files would survive.

## What lives where

| Path | Contents | On | Snapshotted |
|---|---|---|---|
| `/srv/<service>` | Service state and databases — Jellyfin, the \*arr apps, Grafana, Loki, Paperless, Transmission, Bar Assistant, Soularr | zroot | **yes** |
| `/srv/docker` | Docker images, volumes, container state | zroot | **yes** |
| `/var/lib/libvirt` | VM disk images (Home Assistant) | zroot | **yes** |
| `/persist` | Per-aspect service/identity state, bind-mounted back to its usual path | zroot | **yes** |
| `/mnt/ssd/immich` | **Photos and videos** | SSD | no |
| `/mnt/ssd/music` | Music library | SSD | no |
| `/mnt/ssd/downloads` | In-progress and completed downloads (usenet, transmission, slskd) | SSD | no |
| `/mnt/storage/media` | Films and TV — the Jellyfin library | mergerfs | no |
| `/mnt/storage/backup` | Where *other* machines put their backups | mergerfs | no |

Downloads land on the SSD and are moved to `/mnt/storage/media` by the \*arr
apps, which is why the SSD needs headroom even though the library lives
elsewhere.

### Shared write access

Several services write the same directories — Sonarr and Radarr into the media
tree, SABnzbd and Transmission into downloads. That works because of two
settings applied by `modules/lib/servarr.nix`:

- every service user is a member of the group **`tank`**, and
- their units force `UMask=0002`, so new files are group-writable.

If a service suddenly cannot write a file another service created, that pair is
what to check.

## Sharing over the network

Bind mounts in `modules/hosts/thor/nfs.nix` expose three trees under `/export`:

| Export | Real path |
|---|---|
| `/export/media` | `/mnt/storage/media` |
| `/export/downloads` | `/mnt/ssd/downloads` |
| `/export/backup` | `/mnt/storage/backup` |

Two protocols with deliberately different trust levels:

- **NFS** — read-write, but only from the tailnet (`100.64.0.0/10`). Port 2049
  is not opened on the LAN at all; tailnet peers reach it because `tailscale0`
  is a trusted interface. This is how you get write access to thor's storage
  from another machine.
- **Samba** — read-only guest access to `media` and `music`, available on the
  LAN without any credentials. It exists for appliances like Sonos that cannot
  join a tailnet. It cannot write anything.

The rationale for that split is in the comments in `nfs.nix` and `samba.nix`.

## Snapshots

`modules/zfs.nix` keeps automatic snapshots of every dataset with
`com.sun:auto-snapshot=true` — `/srv`, `/var/lib/libvirt`, and `/persist`:

| Frequency | Kept | Covers |
|---|---|---|
| every 15 min | 4 | the last hour |
| hourly | 24 | the last day |
| daily | 7 | the last week |
| weekly | 4 | the last month |
| monthly | 3 | the last quarter |

They cost almost nothing until data changes, and they are the reason a fumbled
config edit or an app that corrupts its own database is a five-minute problem.

### Getting a file back

Every snapshotted dataset has a hidden `.zfs` directory. Nothing needs to be
mounted or restored — just read the old copy out:

```sh
zfs list -t snapshot                      # what's available
ls /srv/.zfs/snapshot/                    # same thing, as directories
cp /srv/.zfs/snapshot/zfs-auto-snap_hourly-2026-08-04-15h00/grafana/grafana.db /tmp/
```

That is the safe operation and covers almost every real case.

To roll an entire dataset back:

```sh
sudo zfs rollback zroot/srv@zfs-auto-snap_daily-2026-08-04-00h00
```

**This destroys every change since that snapshot, for every service on the
dataset**, and deletes any newer snapshots. Stop the affected services first,
and prefer copying individual files unless you genuinely want to rewind
everything under `/srv`.

### Snapshots and free space

Deleting a file from `/srv` does not free space while a snapshot still
references it. If `df` disagrees with what you just deleted:

```sh
zfs list -t snapshot -o name,used -s used   # biggest space-holders last
```

Space returns as those snapshots age out.

## Scrubs

A weekly scrub reads every block in the pool and repairs any that don't match
their checksums, using the mirror's other copy.

```sh
zpool status        # `scan:` shows the last scrub's result
```

`ZfsPoolNotOnline` and `ZfsKernelError` alert on failures here — see
[monitoring.md](monitoring.md). The ext4 disks have no equivalent: nothing
verifies their contents, and silent corruption there is invisible until you open
the file.

## What is not backed up

Modelled on [monitoring.md](monitoring.md#deliberate-omissions) — this is the
honest statement of what is not protected, not a to-do list.

**There is no backup of thor.** Nothing copies thor's data anywhere else — not
to another machine, not to another disk, not off-site. `/mnt/storage/backup` is
a *destination* for other computers; nothing writes thor's own data into it.

**Snapshots are not backups.** They live on the same pool as the data they
protect. They defend against deletion, corruption by an application, and bad
config — all common. They do nothing about a fire, a theft, both NVMe drives
failing, or a filesystem-level disaster.

**Most of the bulk data has neither.** Snapshots cover `/srv`, `/var/lib/libvirt`,
and `/persist` only. Everything on the SSD and on mergerfs — photos, music,
media, and the backup share itself — has no snapshots and no redundancy.

What each loss would actually cost:

| Data | If its disk dies | Recoverable? |
|---|---|---|
| **`/mnt/ssd/immich` — photos** | Gone | **No. Irreplaceable.** |
| `/mnt/ssd/music` | Gone | Only from original media or by re-acquiring |
| `/mnt/storage/media` | Gone | Yes, tediously — the \*arr apps can re-download |
| `/mnt/ssd/downloads` | Gone | Yes, it is transient by nature |
| `/srv/*` service state | Rolled back to a snapshot, if the pool survives | Config comes from this repo; history does not |
| `/var/lib/libvirt` — Home Assistant | Rolled back to a snapshot | Same |
| `/persist` per-aspect state | Rolled back to a snapshot, if the pool survives | Same |
| `/` and `/nix` | Rebuilt by `nixos-rebuild` from this repo | Yes, completely |

The single-sentence summary: **an SSD failure loses the photo library
permanently.** That is the gap worth closing first if backups are ever added.
