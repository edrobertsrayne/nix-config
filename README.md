# NixOS Server Configuration

> Aspect-oriented NixOS configuration following dendritic principles

Server configuration built around
[**dendritic architecture**](https://github.com/mightyiam/dendritic) —
organizing modules by _what they do_ rather than _where they run_. It has two
`nixosConfigurations`: thor, the physical host, and mimir, a
[microvm.nix](https://microvm-nix.github.io/microvm.nix/) guest that thor
hypervises. mimir runs the download stack behind its own Mullvad exit node
(issue #203).

---

## Project Structure

```
modules/           # Aspect-oriented modules (auto-loaded by import-tree)
├── {aspect}.nix   # Single-purpose modules (ssh.nix, docker.nix)
├── {feature}/     # Multi-file features (neovim/, utilities/)
├── hosts/         # Host-specific configs
│   ├── thor/      # Home server (NixOS)
│   └── mimir/     # Download-stack microvm, hypervised by thor
├── downloads/     # Download stack (*arr apps, transmission, and more), runs on mimir
├── settings/      # Project options (user.nix, ports.nix, hosts.nix, server.nix)
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

Every service below runs on **thor**, except the download stack. This guide
calls out the download stack separately: it is the one group that runs on
**mimir** instead. Check this section when you are in doubt about which host
runs a service. This guide groups every service by function, not by host,
except for that one split.

## Host: thor

Home server running NixOS. Everything in this section runs here.

### Media

| | Name | Description |
|---|------|-------------|
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/jellyfin.png" width="20" alt=""> | Jellyfin | Media server |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/jellyseerr.png" width="20" alt=""> | Jellyseerr | Request manager |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/navidrome.png" width="20" alt=""> | Navidrome | Music streaming |
| | MiniDLNA | DLNA media streaming |

The download stack has no privacy requirement of its own on thor. It runs on
mimir instead, so only it needs Mullvad, not the rest of thor. See
[docs/networking.md](docs/networking.md) and "Host: mimir" below.

### Monitoring

| | Name | Description |
|---|------|-------------|
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/grafana.png" width="20" alt=""> | Grafana | Metrics dashboard |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/prometheus.png" width="20" alt=""> | Prometheus | Time-series metrics database |
| | Alertmanager | Alert routing (delivered via ntfy) |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/loki.png" width="20" alt=""> | Loki | Log aggregation |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/grafana-alloy.png" width="20" alt=""> | Alloy | Log shipping agent (Grafana Alloy) |
| | Node Exporter | System metrics |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/openzfs.png" width="20" alt=""> | ZFS Exporter | Filesystem metrics |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/cadvisor.png" width="20" alt=""> | cAdvisor | Container metrics |
| | Smartctl Exporter | Disk health metrics |
| | Blackbox Exporter | HTTP health probes of every proxied service |
| | Docker health collector | Container HEALTHCHECK and running state as textfile metrics |

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

| | Name | Description |
|---|------|-------------|
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/nginx.png" width="20" alt=""> | Nginx | Reverse proxy |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/cloudflare.png" width="20" alt=""> | Cloudflared | Cloudflare tunnel |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/blocky.png" width="20" alt=""> | Blocky | DNS server, ad/tracker/malware blocking |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/tailscale.png" width="20" alt=""> | Tailscale | Mesh VPN |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/docker.png" width="20" alt=""> | Docker | Container runtime |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/portainer.png" width="20" alt=""> | Portainer | Container manager |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/home-assistant.png" width="20" alt=""> | Home Assistant | Home automation (runs in a libvirt VM) |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/homepage.png" width="20" alt=""> | Homepage | Service dashboard |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/vaultwarden.png" width="20" alt=""> | Vaultwarden | Password manager |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/karakeep.png" width="20" alt=""> | Karakeep | Bookmark manager |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/immich.png" width="20" alt=""> | Immich | Photo library |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/paperless-ngx.png" width="20" alt=""> | Paperless | Document management |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/bentopdf.png" width="20" alt=""> | BentoPDF | PDF toolkit |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/bar-assistant.png" width="20" alt=""> | Bar Assistant | Home bar & cocktail manager |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/searxng.png" width="20" alt=""> | SearXNG | Private search engine |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/n8n.png" width="20" alt=""> | n8n | Workflow automation |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/ntfy.png" width="20" alt=""> | ntfy | Push notifications |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/visual-studio-code.png" width="20" alt=""> | Code Server | VS Code in browser |

**Ingress policy:** nginx opens no LAN-reachable port. The only paths in are
the Cloudflare tunnel (`cloudflared` → `127.0.0.1:80`, gated by Cloudflare
Access) and the Tailscale interface (trusted for admin access). Services that
need direct LAN access must open their own port explicitly — the full list, and
the reason for each, is in [docs/networking.md](docs/networking.md).

## Host: mimir

mimir is a [microvm.nix](https://microvm-nix.github.io/microvm.nix/) guest
that thor hypervises. It runs only the download stack below, behind its own
Mullvad exit node, so the rest of thor does not need Mullvad's reliability and
routing quirks (issue #203). Nothing in the sections above runs on mimir.

### Download stack

| | Name | Description |
|---|------|-------------|
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/sonarr.png" width="20" alt=""> | Sonarr | TV series manager |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/radarr.png" width="20" alt=""> | Radarr | Movie manager |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/lidarr.png" width="20" alt=""> | Lidarr | Music manager |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/prowlarr.png" width="20" alt=""> | Prowlarr | Indexer manager |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/bazarr.png" width="20" alt=""> | Bazarr | Subtitle manager |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/transmission.png" width="20" alt=""> | Transmission | Torrent downloader |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/sabnzbd.png" width="20" alt=""> | SABnzbd | Usenet downloader |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/slskd.png" width="20" alt=""> | slskd | Soulseek client |
| <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/soularr.png" width="20" alt=""> | Soularr | Lidarr ↔ slskd bridge |

nginx still runs on thor for these services. It proxies to mimir's static
`br0` address, instead of to loopback. See
[docs/deploying.md](docs/deploying.md#same-host-vs-cross-host-services) for
how a service and its vhost end up split across two hosts.

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
