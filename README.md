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
| Nginx Exporter | Web server metrics |
| ZFS Exporter | Filesystem metrics |
| cAdvisor | Container metrics |
| Smartctl Exporter | Disk health metrics |

### Infrastructure & Applications

| Name | Description |
|------|-------------|
| Nginx | Reverse proxy |
| Cloudflared | Cloudflare tunnel |
| Blocky | DNS server with ad-blocking |
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

- [Neovim Cheatsheet](docs/NEOVIM_CHEATSHEET.md)
- [Tmux Cheatsheet](docs/TMUX_CHEATSHEET.md)
- [CLAUDE.md](CLAUDE.md) - AI agent workflow guidelines

---

## Credits

- [dendrix](https://github.com/vic/dendrix) - Dendritic architecture
- [mightyiam/dendritic](https://github.com/mightyiam/dendritic) - Reference implementation
- [mightyiam/infra](https://github.com/mightyiam/infra) - Personal infra example
- [drupol/infra](https://github.com/drupol/infra) - Another dendritic example
