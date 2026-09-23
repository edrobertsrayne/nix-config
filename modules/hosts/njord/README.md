# njord — host notes

njord is a [microvm.nix](https://microvm-nix.github.io/microvm.nix/) guest.
thor hypervises it (`modules/hosts/thor/_microvm-host.nix`), the same way it
hypervises [mimir](../mimir/README.md). njord exists to run
[Dokploy](https://docs.dokploy.com/), a self-hosted Docker/Swarm-based
deployment platform, so that hosting a new Docker project never requires a
`modules/*.nix` file and a `nixos-rebuild` on thor.

Unlike every other service on thor, Dokploy is **deliberately not declared in
Nix** beyond the guest itself: it installs itself, manages its own Swarm
services, and rewrites its own Traefik config from its UI. njord's job is to
give that statefulness a contained box with Docker and persistent storage
already in place; Dokploy owns everything above that.

---

## Address

| Interface  | Address            | Purpose                                          |
| ---------- | ------------------ | ------------------------------------------------- |
| br0 (tap)  | 192.168.68.130/22  | LAN. Dokploy's UI (`:3000`) is reachable here.     |
| tailscale0 | (registers on first boot) | Mesh VPN, for reaching njord from the tailnet |

Unlike mimir, thor never proxies to njord and holds no concrete tailnet
address for it (`modules/settings/hosts.nix`) — nothing on thor needs to bind
or DNAT to it. njord's own apps are published through **njord's own Cloudflare
tunnel**, run from inside Dokploy, entirely separate from thor's tunnel
(`modules/hosts/thor/thor.nix`).

---

## Managing the VM

Same model as mimir — this is not `virsh`. Run these from thor:

```sh
systemctl status microvm@njord      # is it running
systemctl restart microvm@njord     # restart the whole guest
ssh 192.168.68.130                  # everything else is normal NixOS from here
```

## Deploying config changes

njord is **fully declarative**, exactly like mimir:
`microvm.vms.njord.evaluatedConfig` (`modules/hosts/thor/_microvm-host.nix`)
consumes `nixosConfigurations.njord` directly. Deploying njord is deploying
thor:

```sh
cd ~/config
sudo nixos-rebuild test --flake .#thor    # try it; a reboot reverts it
sudo nixos-rebuild switch --flake .#thor  # make it stick
```

The same caveats mimir's README documents apply here: no
`nixos-rebuild --flake .#njord` on njord itself (read-only `/nix/store` share,
no `nix-daemon`), and no `--target-host njord` from thor either.

**Dokploy itself is the one exception to "config lives in git."** It
self-updates from its own UI and is not touched by thor's nightly
`autoUpgrade` — see the bootstrap section below. Its version is state on the
machine, not a value in this repo.

njord no longer runs its own `nix-gc` or `system.autoUpgrade` timers
(`modules/microvm-guest.nix`): both failed on every scheduled run against the
read-only `/nix/store` share and no `nix-daemon` (#219). thor's own weekly gc
and nightly upgrade already cover the same store, and thor's build already
deploys njord's config — these guest-local timers were pure redundant noise.

njord is monitored the same way mimir is: its own node-exporter and Alloy feed
thor's Prometheus and Loki (`modules/hosts/njord/node-exporter.nix`,
`modules/hosts/njord/alloy.nix`, scraped by
`modules/hosts/thor/njord-scrape.nix`). See [monitoring.md](../../../docs/monitoring.md).

## Storage

- Root is tmpfs, wiped every boot — no root volume is declared below, and
  microvm.nix defaults to a tmpfs root in that case. State that needs to
  survive lives on two image-backed volumes (`/persist` 4 GiB, `/srv` 64 GiB)
  on thor's `zroot/microvms` ZFS dataset (`modules/hosts/thor/disko.nix`),
  snapshotted the same way mimir's are.
- `/srv` carries `/srv/docker` (Docker's data-root) and `/srv/dokploy`, which
  is bind-mounted onto `/etc/dokploy` — Dokploy hardcodes that path for its
  config, Traefik's dynamic config directory, and every app volume it creates.
  Since root is tmpfs (wiped every boot), all of that has to live on `/srv`
  or it disappears at the next boot.
- No `/nix/store` write access, no shared virtiofs mounts from thor's storage
  pools — njord has no reason to touch thor's media/download storage.

## Secrets

None. njord is not an agenix recipient and needs no decryptable secret: the
Cloudflare tunnel token lives inside Dokploy's own Postgres database, created
and stored entirely from the Dokploy UI.

---

## Bootstrapping Dokploy (one-time, after the first successful rebuild)

Everything above is declarative and comes up automatically. Installing
Dokploy itself is the one imperative step, run once on njord:

```sh
ssh 192.168.68.130

# Tailscale needs interactive auth on first boot, same as mimir.
sudo tailscale up

# Docker is already installed and configured by NixOS (common.nix), so the
# installer's own Docker install is skipped. ADVERTISE_ADDR is passed
# explicitly — otherwise the script tries to guess a public IP by calling out
# to ifconfig.io/icanhazip.com, which is pointless on a LAN-only box.
curl -sSL https://dokploy.com/install.sh \
  | sudo ADVERTISE_ADDR=192.168.68.130 sh
```

This initialises a single-node Docker Swarm, creates the `dokploy-network`
overlay network, and starts three things: `dokploy-postgres` and `dokploy`
as Swarm services, and `dokploy-traefik` as a plain container publishing
80/443. All of it lands under `/srv/docker` and `/srv/dokploy` (bind-mounted
at `/etc/dokploy`), both on the `srv.img` volume above.

Then, from `http://192.168.68.130:3000`:

1. Create the admin account immediately — the first visitor to the UI claims
   it.
2. In Cloudflare Zero Trust, create a tunnel and copy its token.
3. In Dokploy, deploy `cloudflare/cloudflared` as an application: command
   `tunnel run`, environment variable `TUNNEL_TOKEN` set to that token,
   attached to `dokploy-network`. See
   [Dokploy's Cloudflare Tunnel guide](https://docs.dokploy.com/docs/core/guides/cloudflare-tunnels).
4. In Cloudflare: set SSL/TLS mode to **Full** (or **Full (Strict)**), add a
   wildcard CNAME for the chosen subdomain pointed at the tunnel, and add a
   public hostname route to `dokploy-traefik:80`.
5. In Dokploy's settings, disable Let's Encrypt — Cloudflare terminates TLS
   at the edge, so njord serves plain HTTP internally.

Once the tunnel is confirmed working, `dokploy-traefik`'s host-published
80/443 are redundant — the tunnel reaches it over the overlay network, not
through those published ports. They can be dropped by recreating that
container without `-p`, closing the only surface Docker opens on the LAN
behind `nixos-fw`. Optional; not yet done as of this writing.
