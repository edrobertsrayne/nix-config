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
├── {feature}/     # Multi-file features (neovim/, utilities/)
├── hosts/         # Host-specific configs
│   └── thor/      # Home server (NixOS)
├── media/         # Media stack (*arr apps, jellyfin)
├── settings/      # Project options (user.nix, ports.nix, server.nix)
├── dashboards/    # Grafana dashboard JSON
└── lib/           # Helper functions

docs/              # Reference documentation
secrets/           # Encrypted secrets (agenix)
```

**Key Concepts:**

- **Dendritic/Aspect-Oriented**: Modules organized by _what they do_, not where they run
- **Auto-Loading**: `import-tree` loads all tracked `.nix` files automatically
- **Underscore Prefix**: Files like `_hardware.nix` require explicit import (safety for host-specific config)
- **Git Tracking Required**: Only git-tracked files are loaded by import-tree

---

## Host: thor

Home server running NixOS, with an impermanent (wipe-on-boot) root and
declared persistence (see
[storage.md](docs/storage.md#impermanence-wipe-on-boot-root)). PostgreSQL is a
shared aspect (`modules/postgresql.nix`) used by Immich and Blocky. Services:

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
| Docker health collector | Container HEALTHCHECK and running state as textfile metrics |

How it all fits together — collection, every alert, and which failure each one
catches — is in [docs/monitoring.md](docs/monitoring.md).

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
[docs/dashboards.md](docs/dashboards.md).

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
| BentoPDF | PDF toolkit |
| Bar Assistant | Cocktail manager |
| SearXNG | Metasearch engine |
| n8n | Workflow automation |
| ntfy | Push notifications |
| Code Server | Browser-based VS Code |

**Ingress policy:** nginx opens no LAN-reachable port. The only paths in are
the Cloudflare tunnel (`cloudflared` → `127.0.0.1:80`, gated by Cloudflare
Access) and the Tailscale interface (trusted for admin access). Services that
need direct LAN access must open their own port explicitly — the full list, and
the reason for each, is in [docs/networking.md](docs/networking.md).

---

## Quick Start

```bash
# Clone
git clone git@github.com:edrobertsrayne/nix-config.git
cd nix-config

# Check it evaluates
nix flake check

# Deploy — pick a verb:
sudo nixos-rebuild test --flake .#thor     # active now, reverts on reboot
sudo nixos-rebuild switch --flake .#thor   # active now, and the boot default
sudo nixos-rebuild boot --flake .#thor     # boot default only (kernel changes)

# Deploy from another machine
nixos-rebuild switch --flake github:edrobertsrayne/nix-config#thor \
  --target-host thor --use-remote-sudo
```

thor also upgrades itself from `main` nightly — see
[deploying.md](docs/deploying.md).

---

## Documentation

**Running the server**

- [Deploying](docs/deploying.md) - the change lifecycle: build, deploy,
  roll back, and the nightly auto-upgrade
- [Troubleshooting](docs/troubleshooting.md) - an alert fired, or something
  broke: what to type, by symptom

**How it is built**

- [Networking](docs/networking.md) - ingress, trust boundaries, and every
  LAN-open port
- [Storage](docs/storage.md) - disks, datasets, what lives where, and what is
  not backed up
- [Monitoring](docs/monitoring.md) - metrics, logs, probes, alerts, and what
  catches which failure
- [Blocky](docs/blocky.md) - DNS: upstream, blocklists, and why there are no
  local records
- [Grafana dashboards](docs/dashboards.md) - provisioning and refreshing them
- [Secrets](.claude/skills/secrets/SKILL.md) - the agenix workflow
- [thor host notes](modules/hosts/thor/README.md) - ports, VMs, and the
  import-tree file conventions

**Personal reference**

- [Neovim cheatsheet](docs/neovim-cheatsheet.md)
- [Tmux cheatsheet](docs/tmux-cheatsheet.md)

---

## Credits

- [dendrix](https://github.com/vic/dendrix) - Dendritic architecture
- [mightyiam/dendritic](https://github.com/mightyiam/dendritic) - Reference implementation
- [mightyiam/infra](https://github.com/mightyiam/infra) - Personal infra example
- [drupol/infra](https://github.com/drupol/infra) - Another dendritic example
