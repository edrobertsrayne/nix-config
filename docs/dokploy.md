# Dokploy on njord

Dokploy is deliberately not declared in Nix beyond the guest. It installs and
updates itself, so its version is state on the machine, not a value in this
repo. njord is not an agenix recipient: the Cloudflare tunnel token lives in
Dokploy's own database.

## Bootstrap (one-time, after the first successful rebuild)

```sh
ssh 192.168.68.130

sudo tailscale up   # interactive auth on first boot

# ADVERTISE_ADDR is required: otherwise the script guesses a public IP.
curl -sSL https://dokploy.com/install.sh \
  | sudo ADVERTISE_ADDR=192.168.68.130 sh
```

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

## Recovering dokploy-traefik

`dokploy-traefik` is a plain container, not a Swarm service, because Dokploy's
Web Server actions act on a container with that name.
`modules/hosts/njord/traefik-watchdog.nix` restarts or recreates it. To keep it
down on purpose, first run `systemctl stop dokploy-traefik-watchdog.timer`.

If the watchdog can't bring it back, check
`journalctl -u dokploy-traefik-watchdog` on njord. Dokploy's Settings > Web
Server > Reload Traefik fails on a missing container. Recreate it with the
arguments from Dokploy's `install.sh` (check the image tag there). Its config in
`/etc/dokploy/traefik` survives:

```sh
ssh 192.168.68.130 'sudo docker run -d \
  --name dokploy-traefik --restart always \
  --network dokploy-network \
  -v /etc/dokploy/traefik/traefik.yml:/etc/traefik/traefik.yml \
  -v /etc/dokploy/traefik/dynamic:/etc/dokploy/traefik/dynamic \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -p 80:80/tcp -p 443:443/tcp -p 443:443/udp \
  traefik:v3.6.25'
```
