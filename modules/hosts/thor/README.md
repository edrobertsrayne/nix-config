# Thor - Home Server

Primary home server running NixOS, hosting media services, monitoring, and
self-hosted applications.

---

## Overview

Thor serves as the central infrastructure hub:

- **Media Server**: Jellyfin streaming with automated acquisition (*arr stack)
- **Home Automation**: Home Assistant VM via libvirt
- **Monitoring**: Prometheus/Grafana/Loki observability stack
- **Self-Hosted Apps**: Password manager, documents, bookmarks, photos, etc.
- **Network Services**: DNS ([Blocky](../../blocky.md)), file sharing (NFS/Samba)

---

## Network Configuration

| Interface  | Address           | Purpose                    |
| ---------- | ----------------- | -------------------------- |
| br0        | 192.168.68.128/22 | Bridge for VMs and LAN     |
| tailscale0 | 100.84.196.40/32  | Mesh VPN (Tailscale)       |

**Domain**: `greensroad.uk` via Cloudflare Tunnel

All services accessible at `{service}.greensroad.uk` through nginx reverse
proxy.

---

## Virtual Machines

Managed via libvirt (libvirtd service).

| VM   | State   | vCPU | RAM | Autostart | Purpose        |
| ---- | ------- | ---- | --- | --------- | -------------- |
| hoas | running | 2    | 4GB | yes       | Home Assistant |

Access Home Assistant at `home.greensroad.uk` or local IP.

---

## Services

### Media Stack

| Service      | Port  | Description              |
| ------------ | ----- | ------------------------ |
| Jellyfin     | 8096  | Media streaming server   |
| Jellyseerr   | 5055  | Media request management |
| Sonarr       | 8989  | TV show management       |
| Radarr       | 7878  | Movie management         |
| Lidarr       | 8686  | Music management         |
| Bazarr       | 6767  | Subtitle management      |
| Prowlarr     | 9696  | Indexer management       |
| Transmission | 9091  | BitTorrent client        |
| Sabnzbd      | 8080  | Usenet client            |
| Flaresolverr | 8191  | Cloudflare bypass        |
| slskd        | 5030  | Soulseek P2P client      |
| Soularr      | 8265  | slskd-to-Lidarr bridge   |
| Navidrome    | 4533  | Music streaming server   |
| MiniDLNA     | 8200  | DLNA media streaming     |

### Monitoring Stack

| Service           | Port | Description               |
| ----------------- | ---- | ------------------------- |
| Prometheus        | 9090  | Metrics database          |
| Alertmanager      | 9093  | Alert routing             |
| Alertmanager-ntfy | 9094  | Alert delivery via ntfy   |
| Grafana           | 3000  | Visualization dashboards  |
| Loki              | 3100  | Log aggregation           |
| Alloy             | 12345 | Log shipper (Grafana Alloy) |
| Node Exporter     | 9100  | System metrics            |
| ZFS Exporter      | 9134  | ZFS pool/dataset metrics  |
| cAdvisor          | 9338  | Container metrics         |
| Smartctl Exporter | 9633  | Disk health metrics       |

### Infrastructure

| Service      | Port      | Description                    |
| ------------ | --------- | ------------------------------ |
| Nginx        | 80/443    | Reverse proxy                  |
| Blocky       | 4000 (53) | DNS with ad/malware blocking   |
| Cloudflared  | -         | Tunnel to Cloudflare           |
| Tailscale    | -         | Mesh VPN                       |
| NFS          | 2049      | Network file sharing (Linux)   |
| Samba        | 445       | Network file sharing (Windows) |

### Applications

| Service       | Port  | Description               |
| ------------- | ----- | ------------------------- |
| Vaultwarden   | 8222  | Password manager          |
| Karakeep      | 8081  | Bookmark manager          |
| Immich        | 2283  | Photo management          |
| Paperless     | 28981 | Document management       |
| Joplin        | 22300 | Note-taking sync server   |
| BentoPDF      | 8085  | PDF manipulation toolkit  |
| Bar Assistant | 8087  | Cocktail manager          |
| SearXNG       | 8083  | Metasearch engine         |
| Homepage      | 8086  | Service dashboard         |
| Code Server   | 8888  | Browser-based VS Code     |
| n8n           | 5678  | Workflow automation       |
| ntfy          | 2586  | Push notification service |

---

## Docker Containers

Managed via Portainer (port 9000/9443).

| Container  | Purpose                    |
| ---------- | -------------------------- |
| portainer  | Container management UI    |
| cleanuparr | Automated media cleanup    |
| huntarr    | Missing media hunter       |

---

## Storage

ZFS pools with NFS/Samba exports for network access.

**Exports**: `/storage/media`, `/storage/downloads`, `/storage/backups`

---

## External Integrations

| Device | Purpose                               |
| ------ | ------------------------------------- |
| PiKVM  | Hardware-level monitoring and control |

PiKVM provides BIOS-level access, power control, and remote console for Thor.

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

- `_hardware.nix` - Hardware configuration

### Auto-Loaded Files

Files without `_` prefix (like `bridge.nix`, `disko.nix`) are auto-loaded by
import-tree. Use this for config that's safe to always enable.

---

## Maintenance

### Common Operations

```bash
# Rebuild and switch
sudo nixos-rebuild switch --flake .#thor

# View service status
systemctl status jellyfin grafana prometheus

# Check VM status
sudo virsh list --all

# View logs
journalctl -u jellyfin -f
```

### Monitoring

- Grafana dashboards: `grafana.greensroad.uk`
- Alertmanager: `alertmanager.greensroad.uk`
- Prometheus targets: `prometheus.greensroad.uk/targets`
