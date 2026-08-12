# mimir — host notes

A [microvm.nix](https://microvm-nix.github.io/microvm.nix/) guest, hypervised
by thor (`modules/hosts/thor/_microvm-host.nix`). Exists to carry the download
stack's Mullvad exit node so the rest of thor doesn't pay for it — see
issue #203 for the full rationale and decision log.

The service inventory lives in the [root README](../../../README.md). Wider
context — trust boundaries, how nginx reaches across hosts, the DNS caveats —
is in [docs/networking.md](../../../docs/networking.md).

---

## Address

| Interface  | Address            | Purpose              |
| ---------- | ------------------ | --------------------- |
| br0 (tap)  | 192.168.68.129/22  | LAN, inbound P2P peers, and how nginx on thor reaches this host (`modules/settings/hosts.nix`) |
| tailscale0 | (registers on first boot) | Mesh VPN, for anything else on the tailnet reaching this host directly by its MagicDNS name |

mimir carries its own Mullvad exit node
(`se-sto-wg-201.mullvad.ts.net`) — thor does not.

Only thor's own br0 address is let through mimir's firewall on the ports
nginx proxies (`modules/hosts/mimir/mimir.nix`) — the rest of the LAN is
blocked from these the same way it's blocked from everything on thor.

---

## Managing the VM

Not `virsh` — this is a declarative microvm.nix guest, run from thor:

```sh
systemctl status microvm@mimir      # is it running
systemctl restart microvm@mimir     # restart the whole guest
ssh mimir                           # everything else is normal NixOS from here
```

## Storage

- Root: two image-backed volumes (`/var`, `/srv`) on thor's `zroot/microvms`
  ZFS dataset (`modules/hosts/thor/disko.nix`), snapshotted the same way
  `/var/lib/libvirt` is. Plain persistent root, **not** impermanent — thor's
  own wipe-on-boot rollback (#163/#167) has no proven pattern here yet.
- `/mnt/ssd/downloads` and `/mnt/storage` are virtiofs shares from thor, not
  separate disks — `df`/`du` for either path shows thor's real, physical
  usage.

## Secrets

Not yet an agenix recipient — its SSH host key only exists once it's actually
provisioned. See the comment in `secrets/secrets.nix`.
