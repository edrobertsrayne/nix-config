# Troubleshooting

Something is broken. This page is organised by what you noticed, not by which
tool you need.

[monitoring.md](monitoring.md) explains how the alerting is designed and why;
this page is what to type when it goes off. If you are looking at a change you
just made rather than a failure, see [deploying.md](deploying.md) — rolling back
is often the fastest fix.

## First moves

Almost every investigation starts with one of these:

```sh
systemctl --failed                  # anything systemd has given up on
journalctl -p err -b --no-pager     # errors since boot
df -h                               # is a disk full
uptime                              # did it reboot without telling you
```

If `systemctl --failed` lists nothing and the disks have space, the problem is
inside a service rather than around it — jump to
[A service is unreachable](#a-service-is-unreachable).

## An alert fired

Alerts arrive on your phone via ntfy. The name in the title maps to a rule in
`modules/alert-rules.nix` (metrics) or `modules/loki.nix` (logs). Each one below
is what it means in plain terms and where to start.

| Alert | What actually happened | Start here |
|---|---|---|
| `ProbeFailed` | A service stopped answering HTTP. The process may still be running — this is the alert that catches "up but broken". | [A service is unreachable](#a-service-is-unreachable) |
| `ProbeSlow` | It answers, but takes >5s. Usually load or a slow database, rarely urgent. | `systemctl status <unit>`, then its logs |
| `SystemdUnitFailed` | A unit died and systemd stopped retrying. The alert names the unit. | `systemctl status <unit>` |
| `SystemdUnitCrashLooping` | A unit keeps dying and restarting, so it never reaches `failed`. Nothing looks wrong in `systemctl --failed`. | `journalctl -u <unit> -e` |
| `ContainerUnhealthy` | A container's own healthcheck is failing while the container stays up. | [Containers](#containers) |
| `ContainerStopped` | A container exists but hasn't run for 10 minutes. In practice this means one started outside Nix, via Portainer. | [Containers](#containers) |
| `ContainerRestartLoop` | More than 3 restarts in 15 minutes. | `docker logs <name>` |
| `HostFilesystemAlmostFull` / `HostFilesystemFillingUp` | A filesystem is below 10% / 20% free. | [Out of disk space](#out-of-disk-space) |
| `MergerfsLowFreeSpace` | `/mnt/storage` has under 100 GiB left. Downloads will start failing before it hits zero. | [Out of disk space](#out-of-disk-space) |
| `HostMemoryAlmostFull` / `HostMemoryHighUsage` | Under 10% / 20% RAM available. Something is about to be OOM-killed. | `btop`, then restart the offender |
| `OomKill` | The kernel already killed something to reclaim memory. | `journalctl -b -g 'Out of memory'` |
| `SystemdCoredump` | A process crashed hard enough to dump core. | `coredumpctl list` |
| `SmartSectorErrors` | A drive is developing bad sectors. **This is the early warning — act on it.** | [Disks and ZFS](#disks-and-zfs) |
| `SmartUnhealthy` | A drive is declaring itself failing. Replace it. | [Disks and ZFS](#disks-and-zfs) |
| `SmartTemperatureHigh` | A drive is over 55°C. Check airflow before it becomes the alert above. | [Disks and ZFS](#disks-and-zfs) |
| `ZfsPoolNotOnline` / `ZfsKernelError` | The ZFS mirror is degraded or logging errors. | [Disks and ZFS](#disks-and-zfs) |
| `HostFanStopped` | The chassis fan is reading 0 RPM. Everything else will follow if this is real. | Check the fan physically; `sensors` |
| `HostHighCpuTemperature` / `HostHighCpuTemperatureWarn` | CPU over 80°C / 72°C. Usually follows the fan alert. | `sensors`, `systemctl status fancontrol` |
| `BlockyResolutionErrors` | DNS is failing for the whole house. | [DNS is broken](#dns-is-broken-everywhere) |
| `BlockyListDownloadsFailing` / `BlockyListRefreshStale` | Ad blocking is quietly degrading; DNS itself still works. | [blocky.md](blocky.md) |
| `InstanceDown` | A metrics exporter is unreachable. Monitoring is partly blind. | `systemctl status prometheus-<name>-exporter` |
| `MonitoringUnitDown` / `LogIngestionStopped` / `AlertmanagerNotificationsFailing` / `PrometheusRuleEvaluationFailures` / `ContainerHealthCollectorStale` | The alerting system itself is broken. Assume you are not being told about other problems. | [monitoring.md runbook](monitoring.md#runbook) |
| `KernelHardFault` | Kernel panic, hard lockup, or machine check exception. Hardware or a bad kernel. | `journalctl -k -b -1` |

Alerts resolve themselves and send a ✅ follow-up. If you are working on a known
problem and want to stop the repeats, silence it rather than ignoring it — see
the `amtool` example in [monitoring.md](monitoring.md#runbook).

## Reading systemd

Nearly everything on thor is a systemd unit, and `systemctl` answers most
questions about it.

```sh
systemctl status jellyfin          # state, recent log lines, PID, memory
systemctl restart jellyfin         # turn it off and on again
systemctl --failed                 # everything that has given up
```

The `Active:` line in `status` is the part to read:

| State | Means |
|---|---|
| `active (running)` | Fine. |
| `active (exited)` | Fine for one-shot setup units — they did their job and stopped. |
| `activating` | Still starting. If it stays here, it is hung, not slow. |
| `failed` | Dead, and systemd has stopped retrying. The reason is in the logs. |
| `inactive (dead)` | Not running and not trying to. Either stopped deliberately or never enabled. |

Logs come from `journalctl`:

```sh
journalctl -u jellyfin -e           # jump to the end (most recent)
journalctl -u jellyfin -f           # follow live, Ctrl-C to stop
journalctl -u jellyfin -b           # this boot only
journalctl -u jellyfin --since '1 hour ago'
journalctl -u jellyfin -p err       # errors only, skip the noise
journalctl -k -b                    # kernel messages
```

Unit names are mostly the obvious thing (`jellyfin`, `nginx`, `grafana`,
`prometheus`, `blocky`, `loki`, `alloy`). The ones that are not:

| Thing | Unit |
|---|---|
| Any Nix-declared container | `docker-<name>.service` — e.g. `docker-soularr.service` |
| Cloudflare tunnel | `cloudflared-tunnel-23c4423f-….service` (tab-completes) |
| Exporters | `prometheus-node-exporter`, `prometheus-zfs-exporter`, `prometheus-smartctl-exporter`, `prometheus-blackbox-exporter` |
| Immich | `immich-server` and `immich-machine-learning` (two units) |

To find one you don't know the name of:

```sh
systemctl list-units --type=service | grep -i immich
```

**Restarting a service is safe** and is the right first response to most
one-off weirdness. It is not a fix for anything that comes back.

## A service is unreachable

The most common failure, and the one with the most places to look. Work from the
inside out — each step rules out a layer.

```sh
# 1. Is the service running at all?
systemctl status jellyfin

# 2. Is it actually answering on its own port? (ports: modules/settings/ports.nix)
curl -sI localhost:8096

# 3. Is nginx proxying it?
curl -sI -H 'Host: jellyfin.greensroad.uk' localhost:80
systemctl status nginx

# 4. Is the tunnel up?
systemctl status 'cloudflared-tunnel-*'
```

**Download-stack services (transmission, sabnzbd, sonarr, radarr, lidarr,
prowlarr, bazarr, slskd, soularr) run on mimir, not thor** (#203). Steps 1 and
2 need `ssh mimir` first — nginx (step 3) still runs on thor and proxies to
mimir's static `br0` address (`modules/settings/hosts.nix`) over the LAN
bridge they share, not the tailnet, so steps 3 and 4 are unchanged. If step 3
passes locally on mimir but nginx on thor still can't reach it, check mimir's
firewall next — it only admits thor's own `br0` address on these ports
(`modules/hosts/mimir/mimir.nix`), so a wrong or changed thor address would
fail exactly this way.

Where it stops tells you what is wrong:

- **Fails at 1** — a service problem. Read its logs.
- **Fails at 2, unit is running** — the service is up but broken internally. This
  is exactly what `ProbeFailed` catches. Its own logs are the only source.
- **Fails at 3** — nginx or the vhost. `nginx -t` and check the module's
  `mkProxiedService` call.
- **Fails at 4** — the tunnel. Everything public is down, not just this service.
- **All four pass but the browser fails** — it is Cloudflare, not thor. Either
  the tunnel's DNS record or Cloudflare Access refusing your login. See
  [networking.md](networking.md).

**The tailnet is the way in when the tunnel is the broken part.** Every service
is reachable from any tailnet device at `thor:<port>` regardless of Cloudflare's
state, and SSH always works there. If `grafana.greensroad.uk` is dead but
`thor:3000` is fine, stop debugging thor and go look at Cloudflare. The
download-stack services are the exception — they're at `mimir:<port>`, not
`thor:<port>`, since #203 moved them off thor.

## DNS is broken everywhere

thor is the whole house's DNS server, so a Blocky failure looks like "the
internet is down" on every device. Confirm it is DNS:

```sh
dig @127.0.0.1 example.com          # is blocky answering
systemctl status blocky
journalctl -u blocky -e
```

**Get the house back online first, fix second.** Point the affected device (or
the router's DHCP) at `1.1.1.1` temporarily — you lose ad blocking, not
connectivity. Then debug at leisure.

The usual cause is the upstream: Blocky resolves over DoH to Mullvad only, with
no plaintext fallback by design. If Mullvad is unreachable, Blocky answers
nothing. [blocky.md](blocky.md) covers the upstream, the bootstrap addresses,
and why it is built that way.

## Out of disk space

```sh
df -h                       # which filesystem
du /mnt/ssd                 # `du` is aliased to ncdu — arrow keys to explore
```

Where it usually goes, in order of likelihood:

| Location | Why it grows | What to do |
|---|---|---|
| `/mnt/ssd/downloads` | Completed downloads never imported, or stalled torrents | Clear them from the SABnzbd/Transmission/slskd UIs |
| `/mnt/storage/media` | The library itself | Add a disk, or delete things |
| `/nix/store` | Old generations | `sudo nix-collect-garbage --delete-older-than 7d` |
| `/srv` | Service state — Loki chunks, Docker images, Paperless originals | `du /srv` and look |
| `/srv` (ZFS, but free space unchanged after deleting) | Snapshots pinning the deleted data | `zfs list -t snapshot -o name,used -s used` |

That last row is the one that will confuse you: on `/srv` and
`/var/lib/libvirt`, deleting a file does not free space if a snapshot still
references it. See [storage.md](storage.md).

Only `/` and `/nix` filling up will actually break the system. A full
`/mnt/storage` breaks downloads and nothing else.

## Containers

Four containers run on thor; Soularr runs on mimir instead since #203 (it
moved with the rest of the download stack it bridges). All are declared in Nix
and therefore managed by systemd. **`systemctl` is the right tool, not
`docker`:**

```sh
systemctl restart docker-soularr    # correct - run this on mimir, not thor
docker restart soularr              # works, but systemd may undo it
```

Inspecting is still Docker's job:

```sh
docker ps -a                        # including stopped ones
docker logs -f soularr
lazydocker                          # a TUI over all of it
```

`ContainerUnhealthy` means the image's own `HEALTHCHECK` is failing —
`docker inspect <name> --format '{{json .State.Health}}' | jq` shows why.

`ContainerStopped` on a container you don't recognise means it was started
outside Nix, through Portainer. Those have no systemd unit, so
`docker_container_running` is the only thing watching them; either adopt it into
a module or remove it.

## Disks and ZFS

```sh
zpool status                        # the mirror's health
zpool status -v                     # plus per-file errors, if any
smartctl -a /dev/sda                # one drive's SMART data
sensors                             # temperatures and fan RPM
```

`zpool status` output to care about: `state: ONLINE` and `errors: No known data
errors`. Non-zero `READ`/`WRITE`/`CKSUM` counters against a device mean that
device is failing, even while the pool still says `ONLINE`.

A weekly scrub reads everything and repairs what it can; the last result is in
the `scan:` line. The pool is a two-disk mirror, so it survives one NVMe failing
— **but `/mnt/disk1` and `/mnt/ssd` are single ext4 disks with no redundancy at
all.** A `SmartSectorErrors` alert against one of those is a warning that data
is at risk, and there is no backup behind it. Read
[storage.md](storage.md#what-is-not-backed-up) before deciding how urgent it is.

## Virtual machines

```sh
sudo virsh list --all               # all VMs and their state
sudo virsh start hoas               # start one
sudo virsh shutdown hoas            # ask it politely
sudo virsh destroy hoas             # pull its power (data loss risk)
sudo virsh console hoas             # serial console; Ctrl-] to exit
```

`hoas` is Home Assistant and autostarts. Its disk lives on
`/var/lib/libvirt`, which *is* snapshotted — see [storage.md](storage.md).

**mimir is not one of these.** It's a [microvm.nix](https://microvm-nix.github.io/microvm.nix/)
guest (#203), declared in Nix rather than run through `virsh` — `virsh list`
will not show it. Use `systemctl status microvm@mimir` on thor instead, and
`ssh mimir` for anything inside it. Its disk images live on
`/var/lib/microvms`, which is snapshotted the same way `/var/lib/libvirt` is.

## When you can't reach thor at all

If SSH is dead over both the tailnet and the LAN, thor is either off, hung, or
has no network.

- The hardware watchdog (`modules/server.nix`) reboots the box automatically if
  the kernel stops responding for 15 seconds, so a genuinely hung machine
  usually recovers on its own. Give it a couple of minutes.
- **PiKVM** is the way in otherwise: it gives you the console, the BIOS, and
  power control as if you were sitting in front of it. Use it to watch the boot,
  pick an older generation from the systemd-boot menu, or power-cycle.
- Nothing will alert you to this. thor monitors thor, so if it is down, the
  thing that would tell you is down too. That is a known gap —
  [monitoring.md](monitoring.md#deliberate-omissions).
