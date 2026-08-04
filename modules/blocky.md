# Blocky

DNS for the whole network, configured by [`modules/blocky.nix`](blocky.nix) and
imported only by thor. It is the LAN's resolver, so a failure here is felt
everywhere — hence `systemd-resolved` is force-disabled rather than left to
compete for port 53.

Two things it does **not** do, both deliberate: it serves no local records (see
[No local records](#no-local-records)), and it never talks to the ISP's
resolver.

## Ports and reachability

| Port | Where | What |
|---|---|---|
| `53` tcp+udp (`ports.dns`) | open on `br0`, the untrusted LAN | thor *is* the LAN's DNS server, so this is one of the few deliberate LAN openings — catalogued in `modules/networking.nix` |
| `4000` (`ports.blocky`) | loopback and tailnet only | Prometheus `/metrics`, and Blocky's REST API |

Port 4000 is not reachable through the Cloudflare tunnel. That is why the
"Blocking control" panel on the `blocky` dashboard — which calls the API *from
the browser* — works from the tailnet but not from outside it.

## Upstream

Queries go to Mullvad over DoH: `https://dns.mullvad.net/dns-query`. Nothing is
sent to the ISP in plaintext.

A DoH-only upstream is circular — resolving `dns.mullvad.net` needs a resolver,
and the resolver is `dns.mullvad.net`. `bootstrapDns` breaks the loop by
pinning the literal addresses `194.242.2.2` and `2a07:e340::2`. If Mullvad ever
renumbers those, blocky cannot start; that is the tradeoff for not falling back
to a plaintext resolver.

Responses are cached for 5m–30m with prefetching enabled, so popular names stay
warm rather than re-resolving on expiry.

## Blocklists

Two groups, both applied to every client (`clientGroupsBlock.default`). Blocky
deduplicates across lists, so the group totals are well below the sum of the
rows. Lists refresh every 4h.

### `ads`

| List | Entries | Blocks |
|---|---:|---|
| [hagezi `pro`](https://github.com/hagezi/dns-blocklists) | 218k | ads, affiliate, tracking, telemetry, phishing, scams, plus error trackers (Sentry, Bugsnag, Crashlytics) |
| [StevenBlack `hosts`](https://github.com/StevenBlack/hosts) | 99k | the long-standing unified ads/malware hosts file |
| [firebog `AdguardDNS`](https://v.firebog.net/hosts/AdguardDNS.txt) | 161k | AdGuard's DNS filter |
| hagezi `popupads` | 54k | pop-up and redirect ad networks |
| inline `adblock.txt` | 3 | a few doubleclick/googlesyndication hosts the lists miss |

`pro` largely supersedes StevenBlack. The overlap is deduplicated and costs
nothing, so StevenBlack stays until there's a reason to drop it.

### `trackers`

| List | Entries | Blocks |
|---|---:|---|
| hagezi `tif.medium` | 386k | malware, phishing, cryptojacking, scams |
| [firebog `Easyprivacy`](https://v.firebog.net/hosts/Easyprivacy.txt) | 43k | the EasyPrivacy tracking list |
| hagezi `native.*` — amazon, apple, huawei, winoffice, tiktok.extended, lgwebos, vivo, oppo-realme, xiaomi | 3k total | vendor telemetry phoned home by devices and smart TVs |
| hagezi `dyndns` | 1.5k | dynamic-DNS providers abused for malware C2 |
| hagezi `hoster` | 1.2k | hosting providers that serve badware |
| inline `trackers.txt` | 25 | session-recording and analytics hosts (Hotjar, Lucky Orange, Mouseflow, Yandex …) |

`tif` also ships a full tier at 2.2M entries. `medium` is the tier that fits a
resolver already holding `pro`; the full one is disproportionate here.

### Why the URLs look the way they do

Every hagezi list is fetched from
`raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/`. Both halves of
that matter, and both are the result of a breakage:

- **Not jsDelivr.** The lists used to come from
  `cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/…`. The repo outgrew
  jsDelivr's 150 MB per-package cap, and the CDN now returns **403** for the
  whole package — every list at once.
- **Not `domains/`.** Upstream deleted that directory, so retargeting the host
  alone still 404s.
- **`wildcard/`, not `adblock/`.** `wildcard/` holds `*.example.com` entries and
  is the format hagezi recommends for blocky. The `adblock/` copy of every list
  is ABP syntax (`||example.com^`), **which blocky cannot parse** — it reads
  hosts files, plain domain lists, wildcards and regex only. A list in the wrong
  format loads as zero entries without an obvious error.

## Allowlist

`allowlists.ads` carries a small inline list of Google and YouTube endpoints
that the ad lists catch as collateral: Play Store and app update paths
(`android.clients.google.com`, `dl.google.com`, `redirector.gvt1.com`), push
notifications (`mtalk.google.com`), YouTube playback and stats, and the
`googleapis.com` endpoints that Android apps need for sign-in, reminders and
Firestore. Without these, Android devices break in ways that don't obviously
look like DNS.

This is the place to add entries when a legitimate site gets blocked — see
[Runbook](#runbook).

## No local records

Blocky serves **no** records for `greensroad.uk`, and there is no split-horizon
DNS. A record set was added once and reverted (`32d13d2`, `d8e131f`).

The consequence is load-bearing for several services. A phone or TV on the
tailnet cannot reach `photos.greensroad.uk` and land on thor directly — that
name resolves publicly, through the Cloudflare tunnel, and Cloudflare Access
gates it with a Google login that mobile apps can't complete. So those clients
connect by **tailnet IP and port** instead, which is why Immich, Jellyfin and
Navidrome bind `0.0.0.0` rather than loopback.

Binding `0.0.0.0` is not what makes them reachable — the firewall is the actual
boundary. None of them set `openFirewall` (which would open the port on *every*
interface); only loopback (nginx) and `tailscale0` (a trusted interface) can
reach them. Jellyfin additionally opens `8096` on `br0` for LAN players, scoped
explicitly.

## Query log

Every query is logged to postgres over the unix socket
(`postgres://blocky@/blocky?host=/run/postgresql`), retained 30 days. Blocky
creates the `log_entries` table itself at runtime, which is why the `grafana`
role's `SELECT` grant can't be declared as schema and is applied by the
`blocky-grafana-grants` oneshot instead — it covers both existing tables and,
via `ALTER DEFAULT PRIVILEGES`, ones blocky creates later.

The `grafana` role is only created when grafana is enabled, so a host without it
isn't left with a stranded role.

## Monitoring

Dashboards `blocky` (metrics) and `blocky-query` (the postgres log) — see
[dashboards/README.md](dashboards/README.md).

Three alerts in `modules/alert-rules.nix`, group `dns-health`:

| Alert | Fires when |
|---|---|
| `BlockyResolutionErrors` | `blocky_error_total` increases — usually Mullvad unreachable. Critical. |
| `BlockyListDownloadsFailing` | any blocklist download fails within the hour |
| `BlockyListRefreshStale` | lists haven't refreshed in 48h |

The two list alerts exist because `loading.strategy = "fast"` means blocky
serves DNS regardless of blocklist state. **Nothing user-visible breaks when a
list dies** — blocking just quietly degrades. In August 2026 all ten hagezi
lists had been 403ing long enough to reach 30 failed downloads, leaving
`trackers` running on Easyprivacy and the inline list alone. Treat these two as
real; they are the only signal.

Note the shape of `BlockyListDownloadsFailing`: `increase(...[1h]) > 0` against
a 4h refresh means it fires for an hour after each failed refresh and then goes
quiet, rather than staying lit.

## Runbook

Check list health:

```sh
curl -s http://127.0.0.1:4000/metrics | grep -E '^blocky_(failed_downloads|denylist_cache|error_total)'
```

`blocky_failed_downloads_total` is a counter that resets on restart; anything
above zero and climbing means a list is dead. `blocky_denylist_cache_entries`
should be roughly 530k for `ads` and 435k for `trackers` — a group far below
that has lost a list, or gained one in a format blocky can't parse.

Find the failure:

```sh
journalctl -u blocky --since '-1h' | grep -iE 'list_cache.*(error|403|404)'
```

Confirm a domain's verdict (`0.0.0.0` means blocked):

```sh
dig +short @127.0.0.1 example.com
```

**A legitimate site is blocked.** Find what was blocked and by which group in
the `blocky-query` dashboard, then add the domain to the inline `whitelist.txt`
in `allowlists.ads` in `blocky.nix` and rebuild. Prefer allowlisting the
specific name over dropping a whole list.

Force a refresh without a rebuild — useful when testing a list change:

```sh
systemctl restart blocky
```
