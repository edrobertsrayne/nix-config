# mimir — host notes

mimir is a [microvm.nix](https://microvm-nix.github.io/microvm.nix/) guest.
thor hypervises it (`modules/hosts/thor/_microvm-host.nix`). mimir exists to
carry the download stack's Mullvad exit node, so the rest of thor does not
need it. See issue #203 for the full rationale and decision log.

The service inventory lives in the [root README](../../../README.md).
[docs/networking.md](../../../docs/networking.md) covers the wider context:
trust boundaries, how nginx reaches across hosts, and the DNS caveats.

---

## Address

| Interface  | Address            | Purpose              |
| ---------- | ------------------ | --------------------- |
| br0 (tap)  | 192.168.68.129/22  | LAN, inbound P2P peers, and how nginx on thor reaches this host (`modules/settings/hosts.nix`) |
| tailscale0 | (registers on first boot) | Mesh VPN, for anything else on the tailnet reaching this host directly by its MagicDNS name |

mimir carries its own Mullvad exit node (`se-sto-wg-201.mullvad.ts.net`).
thor does not carry one.

mimir's firewall lets through only thor's own br0 address, on the ports that
nginx proxies (`modules/hosts/mimir/mimir.nix`). The firewall blocks the rest
of the LAN from these ports, the same way thor blocks the rest of the LAN
from everything on thor.

---

## Managing the VM

This is not `virsh`. mimir is a declarative microvm.nix guest. Run these
commands from thor:

```sh
systemctl status microvm@mimir      # is it running
systemctl restart microvm@mimir     # restart the whole guest
ssh 192.168.68.129                  # everything else is normal NixOS from here
```

`ssh mimir` over the tailnet is refused (`tailnet policy does not permit you to SSH
to this node`) — thor is tagged `tag:server`, mimir is untagged, and neither ACL
rule matches that combination. Use the LAN address until the tailnet policy is
updated to allow `tag:server` → `tag:server`.

## Deploying config changes

mimir is **fully declarative**: its system is built as part of thor's build —
`microvm.vms.mimir.evaluatedConfig` (`modules/hosts/thor/_microvm-host.nix`)
consumes `nixosConfigurations.mimir` directly. Deploying mimir is deploying
thor:

```sh
cd ~/config
sudo nixos-rebuild test --flake .#thor    # try it; a reboot reverts it
sudo nixos-rebuild switch --flake .#thor  # make it stick
```

When a rebuild changes mimir's configuration, the `microvm@mimir` service
restarts — the whole guest, not a rolling update (`restartIfChanged`,
`modules/hosts/thor/_microvm-host.nix`). That includes thor's nightly
autoUpgrade at 04:00, so **anything merged to `main` reaches mimir within a
day**, the same "merging is deploying" model as thor
([docs/deploying.md](../../../docs/deploying.md#the-nightly-upgrade)). Rolling
thor back to an older generation rolls mimir's config back with it, on the
next restart or reboot.

Two paths that work for ordinary hosts do **not** apply to mimir, and are not
needed:

- `nixos-rebuild switch --flake .#mimir` on mimir itself: mimir shares thor's
  `/nix/store` read-only over virtiofs and does not run `nix-daemon`, so it
  cannot build or activate a closure on its own behalf.
- `nixos-rebuild switch --target-host mimir` from thor: fails for the same
  reason (`nix-copy-closure`/`nix copy` has no working store to land a
  closure on) with a misleading local-looking error — `error: creating
  directory "/nix/var/nix/temproots": Permission denied` / `error: cannot
  connect to '<ip>'` — that is actually the guest rejecting the copy, not a
  local permission or SSH problem. Root SSH login is also disabled on mimir
  (`PermitRootLogin = "no"`, `modules/ssh.nix`), so a `root@<ip>` target
  fails separately with a publickey error.

The old host-side CLI flow (`sudo microvm -R -u mimir`) is obsolete. It was
the update path while mimir ran in microvm.nix's "declarative deployment"
mode, where `microvm -u` builds from the flake pointer file
`/var/lib/microvms/mimir/flake` — a file every thor rebuild re-pinned to a
frozen store-path snapshot of the flake, which silently deployed stale
changes (#203). In fully-declarative mode microvm.nix reads no pointer file;
nothing consumes `microvm -u` anymore. If a leftover `flake` file still
exists in `/var/lib/microvms/mimir/`, it is dead and safe to delete.

## Storage

- Root: two image-backed volumes (`/persist`, `/srv`) on thor's
  `zroot/microvms` ZFS dataset (`modules/hosts/thor/disko.nix`), snapshotted
  the same way `/var/lib/libvirt` is. This is a plain persistent root, **not**
  an impermanent one. thor's own wipe-on-boot rollback (#163/#167) has no
  proven pattern here yet.
- `/mnt/ssd/downloads` and `/mnt/storage` are virtiofs shares from thor, not
  separate disks. `df` and `du` show thor's real, physical usage for either
  path.

## Secrets

mimir is not yet an agenix recipient. Its SSH host key exists only once it is
actually provisioned. See the note in `secrets/secrets.nix`.

## State migration (2026-08-26)

The download stack's app state (sonarr/radarr/lidarr/bazarr/prowlarr databases,
sabnzbd/slskd histories, transmission's torrents, soularr's progress) was copied
from thor to mimir on 2026-08-26, once the services themselves were confirmed
reachable but starting from empty databases. Source paths on thor mirrored
mimir's own layout (`/srv/<app>` for the four *arr apps, `/persist/var/lib/...`
for the rest); the transfer used a `tar | ssh | tar` pipe, since neither
`rsync` nor `nix-copy-closure`-style tooling has a working root path here (thor
root has no SSH key; mimir refuses root logins).

thor's original copies were **left in place**, not deleted — they're the
fallback if anything about the migrated data turns out wrong.

Two paths are impermanence bind-mounts on mimir (`modules/persistence.nix`):
`/var/lib/sabnzbd`, `/var/lib/slskd`, and `/var/lib/private` (which holds
prowlarr). Re-copying into these must clear the directory's *contents*, not
the directory itself, or the bind mount goes with it.

This migration also surfaced two bugs specific to reaching mimir over
`tailscale0` instead of `br0` (see `modules/settings/hosts.nix`,
`thor.tailnetAddress` / `mimir.tailnetAddress`): transmission's
`rpc-whitelist` is IP-based and only recognized thor's LAN address, and
soularr's podman port-publish was bound to mimir's LAN address only. Both are
fixed in the relevant modules; the general pattern — anything that whitelists
or binds by IP rather than relying on the firewall/Host header — needs thor's
tailnet address too, now that nginx's `proxyPass` targets resolve there.
