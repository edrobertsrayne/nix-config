# nix-config

NixOS configuration for thor and its microvm guests (mimir, njord), plus an rpi5
bootstrap image. See `CLAUDE.md` for conventions and `docs/` for runbooks.

Not declared here:

- libvirt VMs on thor (`hoas`, Home Assistant): runtime state, managed with
  `virsh`. Their images are on the snapshotted `zroot/libvirt` dataset.
- Dokploy and its apps on njord: see `docs/dokploy.md`.
- The odin and freyja laptops, which back up to thor: see `docs/backup.md`.
- PiKVM: console, BIOS and power control for thor when SSH is gone.
