# Networking

How traffic reaches thor, which paths are trusted, and why almost nothing is
exposed to the LAN.

The governing idea: **the LAN is not trusted.** thor treats the home network the
same way it treats the internet. Access comes through one of two gated paths,
and the handful of ports open on the LAN are each there for a specific appliance
that cannot use either path.

## The two ways in

### Cloudflare tunnel — for browsers, from anywhere

`cloudflared` (`modules/hosts/thor/thor.nix`) holds an outbound connection to
Cloudflare and forwards `*.greensroad.uk` to nginx on `127.0.0.1:80`. Anything
not matching returns 404.

Nothing is port-forwarded on the router: the tunnel dials out, so there is no
inbound hole to attack. **Authentication is Cloudflare Access**, which requires
a Google login before a request ever reaches thor. Access policies are
configured in the Cloudflare dashboard, not in this repo — there is no password
layer in the Nix config because Access *is* the auth layer.

### Tailscale — for admin, from your devices

`tailscale0` is the **only** entry in `networking.firewall.trustedInterfaces`
(`modules/tailscale.nix`). Every port thor listens on is reachable from a
tailnet peer at `thor:<port>` without opening anything on the LAN. That is why
Prometheus, Alertmanager and the rest need no vhost.

`--ssh` is set, so SSH to thor is authorised by tailnet ACLs (also configured in
the Tailscale admin console, out of band). thor's tailnet address is
`100.84.196.40`.

thor also uses a Mullvad exit node (`se-sto-wg-201.mullvad.ts.net`) with
`--exit-node-allow-lan-access`. A routing policy rule named `40-br0`
(`modules/hosts/thor/bridge.nix`) keeps traffic originating from the LAN address
on the main routing table, so LAN service traffic does not get pushed through
Sweden.

### nginx sits behind both

nginx (`modules/nginx.nix`) terminates every `*.greensroad.uk` vhost and proxies
to the service's real port. It **opens no firewall port at all** — it is
reachable from loopback (which is how the tunnel reaches it) and from the
tailnet, and nowhere else.

Most vhosts are generated rather than written: `mkProxiedService`
(`modules/lib/proxy.nix`) creates the vhost, the Homepage tile and the health
probe from one call.

## The LAN

`br0` bridges thor's four NICs (`enp2s0`–`enp5s0`) into one interface at a
static `192.168.68.128/22`, gateway `192.168.68.1`
(`modules/hosts/thor/bridge.nix`). The bridge exists so libvirt VMs get real
addresses on the home network rather than being NAT-ed behind thor.

thor's own upstream resolvers are Mullvad, Cloudflare and Google
(`194.242.2.2`, `1.1.1.1`, `8.8.8.8`) — deliberately not Blocky, so that a
Blocky outage does not also stop thor from resolving names to fix itself.

## What is open on the LAN, and why

Everything below is reachable from any device on the home network. This is the
complete list — the catalogue comment in `modules/networking.nix` explains the
policy behind it.

| Port | Service | Why it is LAN-open |
|---|---|---|
| 22/tcp | SSH | Key-only admin access |
| 53/tcp+udp | Blocky | thor *is* the network's DNS server |
| 137,138/udp · 139,445/tcp | Samba | Guest read-only media/music for appliances (Sonos) |
| 1900/udp · 8200/tcp | MiniDLNA | DLNA discovery is link-local by design |
| 5353/udp | Avahi | mDNS service discovery is link-local |
| 51413/tcp+udp | Transmission | Inbound BitTorrent peers, forwarded at the router |
| 50300/tcp | slskd | Inbound Soulseek peers, forwarded at the router |
| 41641/udp | Tailscale | Tailnet transport |

Two openings are scoped to a single interface rather than being global:

| Port | Interface | Why |
|---|---|---|
| 8096/tcp · 1900,7359/udp | `br0` | Jellyfin for LAN players; Jellyfin does its own auth |
| 5030, 8686/tcp | `docker0` | Lets the Soularr container reach slskd and Lidarr via `host.docker.internal` |

**NFS is not in either list.** Port 2049 is closed on the LAN; NFS is
tailnet-only, and reachable there only because `tailscale0` is trusted. See
[storage.md](storage.md#sharing-over-the-network).

To check the live state rather than trusting this table:

```sh
nix eval --raw .#nixosConfigurations.thor.config.networking.firewall.allowedTCPPorts \
  --apply 'builtins.toString'
```

## Split-horizon DNS for the tailnet, not the LAN

Blocky resolves `*.greensroad.uk` straight to thor's tailnet address
(`100.84.196.40`) for any client that uses it — see
[blocky.md](blocky.md#split-horizon-greensroaduk) for the mapping and why it's
safe. LAN devices don't take DNS from blocky (the router hands out its own
resolver on `192.168.68.1`), so this split only ever applies on the tailnet; a
device on the LAN asking for `photos.greensroad.uk` still gets Cloudflare's
public answer and goes out to the internet and back through the tunnel, even
standing next to the server.

This has one consequence worth knowing because it explains several odd-looking
module settings, and it survives the split-horizon change even though it looks
at first like it shouldn't:

**Mobile apps still connect by `100.84.196.40:<port>`, not by hostname**, even
though the hostname now resolves straight to thor for any tailnet client
(blocky is the tailnet's global nameserver, reachable from anywhere Tailscale
is connected — not just at home). Availability is identical either way: both
paths need Tailscale up. The difference is the *failure* mode when it isn't.
An IP:port app with Tailscale down gets a clean connection timeout. A
hostname-based app in the same state falls back to public DNS, resolves to
Cloudflare, and gets served the Access login page as a 302 — which some mobile
HTTP clients mishandle as a corrupt session rather than an obvious auth
failure. So the Immich, Navidrome and Jellyfin apps keep the IP:port config,
and those services bind `0.0.0.0` rather than loopback so the tailnet
interface can reach them, while still not appearing in the firewall table
above. Binding `0.0.0.0` with no firewall opening means "tailnet-reachable,
not LAN-reachable", and that combination is intentional wherever you see it.

Paperless binds `0.0.0.0` for the same reason, even though it has no mobile
app in this config — it's the general escape hatch for reaching an
Access-gated service's API directly (e.g. from a script or another tailnet
device) without a browser login flow. On that path paperless's own login is
the only gate; Cloudflare Access never sees tailnet-direct traffic.

## Choosing how to reach a service

| From | Use |
|---|---|
| A browser, anywhere | `https://<service>.greensroad.uk` — through the tunnel, Access login |
| A browser, on the tailnet | Same hostname now resolves straight to thor over `:443` — no Access login, no tunnel hop |
| A mobile app | `100.84.196.40:<port>` over the tailnet — same availability as the hostname, but fails clean (timeout, not an Access login page) if Tailscale drops |
| Admin tools with no vhost (Prometheus, Alertmanager) | `thor:<port>` from a tailnet device |
| A LAN appliance that can't do either | Only the ports in the table above |

When the public hostname fails but the tailnet address works, the fault is
Cloudflare's — see
[troubleshooting.md](troubleshooting.md#a-service-is-unreachable).
