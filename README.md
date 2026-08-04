# NixOS Server Configuration

> Aspect-oriented NixOS configuration following dendritic principles

Single-host server configuration built around
[**dendritic architecture**](https://github.com/mightyiam/dendritic) —
organizing modules by _what they do_ rather than _where they run_.

---

## Project Structure

```
modules/           # Aspect-oriented modules (auto-loaded by import-tree)
├── {aspect}.nix   # Single-purpose modules (ssh.nix, docker.nix)
├── {feature}/     # Multi-file features (nixvim/)
├── hosts/         # Host-specific configs
│   └── thor/      # Home server (NixOS)
├── media/         # Media stack (*arr apps, jellyfin)
├── settings/      # Project options (user.nix, ports.nix, server.nix)
└── lib/           # Helper functions

docs/              # Reference documentation (cheatsheets)
secrets/           # Encrypted secrets (agenix)
```

**Key Concepts:**

- **Dendritic/Aspect-Oriented**: Modules organized by _what they do_, not where they run
- **Auto-Loading**: `import-tree` loads all tracked `.nix` files automatically
- **Underscore Prefix**: Files like `_hardware.nix` require explicit import (safety for host-specific config)
- **Git Tracking Required**: Only git-tracked files are loaded by import-tree

---

## Host: thor

Home server running NixOS. Services:

### Media

| Name | Description |
|------|-------------|
| Jellyfin | Media server |
| Jellyseerr | Media request management |
| Sonarr | TV show management |
| Radarr | Movie management |
| Lidarr | Music management |
| Prowlarr | Indexer management |
| Bazarr | Subtitle management |
| Transmission | BitTorrent client |
| Sabnzbd | Usenet client |
| slskd | Soulseek P2P client |
| Soularr | Bridges slskd downloads to Lidarr |
| Navidrome | Music streaming server |
| MiniDLNA | DLNA media streaming |

### Monitoring

| Name | Description |
|------|-------------|
| Grafana | Metrics visualization |
| Prometheus | Time-series metrics database |
| Alertmanager | Alert routing (delivered via ntfy) |
| Loki | Log aggregation |
| Alloy | Log shipping agent (Grafana Alloy) |
| Node Exporter | System metrics |
| ZFS Exporter | Filesystem metrics |
| cAdvisor | Container metrics |
| Smartctl Exporter | Disk health metrics |
| Blackbox Exporter | HTTP health probes of every proxied service |

Probes are contributed by each service via `monitoring.probeTargets`, keyed by
the service's display name — that key becomes the probe's `instance` label, so
Grafana legends and ntfy alerts name the service rather than a loopback port.
Where a service exposes a health endpoint reachable without an API key, the
probe targets that (`probePath` on `mkProxiedService`) rather than `/`: hitting
the root only proves something is listening, which a service with an unopenable
database will happily keep doing.

Grafana dashboards are provisioned from `modules/dashboards/`, contributed by
the module owning the metrics each one displays (`monitoring.dashboards`). They
are read-only in the browser — edit the JSON and rebuild. See
[modules/dashboards/README.md](modules/dashboards/README.md).

### Infrastructure & Applications

| Name | Description |
|------|-------------|
| Nginx | Reverse proxy |
| Cloudflared | Cloudflare tunnel |
| Blocky | DNS server, ad/tracker/malware blocking |
| Tailscale | Mesh VPN |
| Docker | Container runtime |
| Portainer | Container management UI |
| Libvirt | Virtual machine host (Home Assistant) |
| Homepage | Service dashboard |
| Vaultwarden | Password manager |
| Karakeep | Bookmarking |
| Immich | Photo management |
| Paperless | Document management |
| Joplin | Note-taking sync server |
| BentoPDF | PDF toolkit |
| Bar Assistant | Cocktail manager |
| SearXNG | Metasearch engine |
| n8n | Workflow automation |
| ntfy | Push notifications |
| Code Server | Browser-based VS Code |

**Ingress policy:** nginx opens no LAN-reachable port. The only paths in are
the Cloudflare tunnel (`cloudflared` → `127.0.0.1:80`, gated by Cloudflare
Access) and the Tailscale interface (trusted for admin access). Services that
need direct LAN access must open their own port explicitly.

---

## Quick Start

```bash
# Clone
git clone git@github.com:edrobertsrayne/nix-config.git
cd nix-config

# Deploy
sudo nixos-rebuild switch --flake .#thor

# Deploy from remote
nixos-rebuild switch --flake github:edrobertsrayne/nix-config#thor \
  --target-host thor --use-remote-sudo
```

---

## Documentation

- [Blocky](modules/blocky.md) - DNS: upstream, blocklists, and why there are no
  local records
- [Grafana dashboards](modules/dashboards/README.md)
- [Neovim Cheatsheet](docs/NEOVIM_CHEATSHEET.md)
- [Tmux Cheatsheet](docs/TMUX_CHEATSHEET.md)
- [CLAUDE.md](CLAUDE.md) - AI agent workflow guidelines

---

## Credits

- [dendrix](https://github.com/vic/dendrix) - Dendritic architecture
- [mightyiam/dendritic](https://github.com/mightyiam/dendritic) - Reference implementation
- [mightyiam/infra](https://github.com/mightyiam/infra) - Personal infra example
- [drupol/infra](https://github.com/drupol/infra) - Another dendritic example
