# Thor — host notes

Host-specific details for thor that don't belong in a general reference doc:
addresses, VMs, ports, and the file conventions that govern this directory.

The service inventory lives in the [root README](../../../README.md). How the
box is built and run is in [`docs/`](../../../docs):
[deploying](../../../docs/deploying.md),
[troubleshooting](../../../docs/troubleshooting.md),
[networking](../../../docs/networking.md),
[storage](../../../docs/storage.md),
[monitoring](../../../docs/monitoring.md).

---

## Addresses

| Interface  | Address           | Purpose                |
| ---------- | ----------------- | ---------------------- |
| br0        | 192.168.68.128/22 | Bridge for VMs and LAN |
| tailscale0 | 100.84.196.40/32  | Mesh VPN (Tailscale)   |

**Domain**: `greensroad.uk` via Cloudflare Tunnel. Services are reached at
`{service}.greensroad.uk` through nginx, or at `100.84.196.40:{port}` from the
tailnet — see [networking.md](../../../docs/networking.md).

---

## Virtual Machines

Managed via libvirt. VMs are runtime state, not declared in Nix — `virsh` is the
interface.

| VM       | State    | vCPU | RAM | Autostart | Purpose        |
| -------- | -------- | ---- | --- | --------- | -------------- |
| hoas     | running  | 2    | 4GB | yes       | Home Assistant |
| openclaw | shut off | 4    | 8GB | no        | Scratch VM     |

Their disk images live on `/var/lib/libvirt`, which is snapshotted.

---

## Ports

`modules/settings/ports.nix` is the source of truth — it is what the modules
actually read. This table is a convenience copy; if they disagree, the Nix wins.

| Service           | Port  |     | Service       | Port  |
| ----------------- | ----- | --- | ------------- | ----- |
| Jellyfin          | 8096  |     | Vaultwarden   | 8222  |
| Jellyseerr        | 5055  |     | Karakeep      | 8081  |
| Sonarr            | 8989  |     | Immich        | 2283  |
| Radarr            | 7878  |     | Paperless     | 28981 |
| Lidarr            | 8686  |     | BentoPDF      | 8085  |
| Bazarr            | 6767  |     | Bar Assistant | 8087  |
| Prowlarr          | 9696  |     | SearXNG       | 8083  |
| Sabnzbd           | 8080  |     | Homepage      | 8086  |
| Transmission      | 9091  |     | Code Server   | 8888  |
| Flaresolverr      | 8191  |     | n8n           | 5678  |
| slskd             | 5030  |     | ntfy          | 2586  |
| Soularr           | 8265  |     | Portainer     | 9000  |
| Navidrome         | 4533  |     | Blocky (API)  | 4000  |
| MiniDLNA          | 8200  |     | Nginx         | 80    |
|                   |       |     |               |       |
| Prometheus        | 9090  |     | Node Exporter | 9100  |
| Alertmanager      | 9093  |     | ZFS Exporter  | 9134  |
| Alertmanager-ntfy | 9094  |     | cAdvisor      | 9338  |
| Grafana           | 3000  |     | Smartctl Exp. | 9633  |
| Loki              | 3100  |     | Blackbox Exp. | 9115  |
| Alloy             | 12345 |     |               |       |

---

## Docker Containers

Declared in Nix (`virtualisation.oci-containers`) and therefore managed by
systemd as `docker-<name>.service`. Also inspectable via Portainer.

| Container            | Purpose                    |
| -------------------- | -------------------------- |
| portainer            | Container management UI    |
| bar-assistant-server | Bar Assistant API          |
| salt-rim             | Bar Assistant frontend     |
| meilisearch          | Bar Assistant search index |
| soularr              | slskd-to-Lidarr bridge     |

Containers started outside Nix (through Portainer) have no systemd unit, so
`ContainerStopped` from `docker_container_running` is the only thing watching
them.

---

## Storage

Two NVMe drives in a ZFS mirror, plus unredundant ext4 disks pooled with
mergerfs. Layout, what lives where, the NFS/Samba exports, and what is *not*
backed up: [storage.md](../../../docs/storage.md).

`zroot/root` (`/`) is wiped to a blank snapshot on every boot — impermanent by
design, via a stage-1 initrd service. `zroot/persist` (`/persist`) and
`zroot/home` (`/home`) are not: they carry declared service/identity state and
user files across the wipe, each aspect declaring its own paths directly
(no central list). Full model, the rollback mechanism, and further reading:
[storage.md#impermanence-wipe-on-boot-root](../../../docs/storage.md#impermanence-wipe-on-boot-root).

---

## External Integrations

| Device | Purpose                               |
| ------ | ------------------------------------- |
| PiKVM  | Hardware-level monitoring and control |

PiKVM provides BIOS-level access, power control, and remote console — the way in
when SSH is gone. Not configured in this repo.

---

## Maintenance

Root (`/`) is ephemeral — wiped to a blank snapshot on every boot. Any new
state that needs to survive a reboot must be declared explicitly, either in
the owning aspect or in `modules/persistence.nix`; anything not declared is
lost. Verify with `touch /canary && sudo reboot` — if `/canary` is gone
afterwards, the wipe fired.

---

## File Organization

- `thor.nix` - Main host configuration (import this)
- `_*.nix` - Implementation modules (private to thor)
- Other `.nix` files - Auto-loaded by import-tree

### Underscore Prefix Convention

Files with `_` prefix are:

- Tracked in git (for version control)
- Excluded from automatic import-tree loading
- Manually imported by `thor.nix` for explicit dependencies
- Host-specific implementations not meant for reuse

### Current Private Modules

- `_hardware.nix` - Hardware config generated by `nixos-generate-config`
- `_rollback.nix` - Root-wipe-on-boot initrd service (impermanence, #163).
  Underscore-prefixed so it only activates via explicit `thor.nix` import.

### Auto-Loaded Files

Files without `_` prefix (like `bridge.nix`, `disko.nix`) are auto-loaded by
import-tree. Use this for config that's safe to always enable. Note that
import-tree only loads **git-tracked** files — a new module does nothing until
it is `git add`-ed.

Every file in this directory contributes to the same `flake.modules.nixos.thor`
aspect; they merge rather than override.
