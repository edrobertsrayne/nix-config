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
ssh mimir                           # everything else is normal NixOS from here
```

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
