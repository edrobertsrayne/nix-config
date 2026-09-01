# Monitoring

Everything thor knows about itself, and how a failure becomes a phone
notification. The stack spans a dozen modules; this is the map.

This page is the design reference — why the pipeline is shaped this way and
what each alert exists to catch. If one has just fired and you want to know what
to type, start at [troubleshooting.md](troubleshooting.md).

The governing rule: **every failure class must reach ntfy**. A dashboard nobody
is looking at is not monitoring. Signals that only feed a dashboard are called
out as such in [Deliberate omissions](#deliberate-omissions).

## Pipeline

```mermaid
flowchart LR
  subgraph collect[Collection]
    E["exporters<br/>node · zfs · smartctl · cAdvisor · blocky"]
    T["textfile collector<br/>docker health"]
    B["blackbox-exporter<br/>HTTP probes"]
    J["journald"]
  end

  E --> P[Prometheus]
  T --> E
  B --> P
  J --> AL[Alloy] --> L[Loki]

  P -->|alert-rules.nix| AM[Alertmanager]
  L -->|ruler| AM
  AM --> N[alertmanager-ntfy] --> NT[ntfy] --> Phone
  P --> G[Grafana]
  L --> G
```

Two rule engines, one Alertmanager. Prometheus evaluates metric rules; Loki's
ruler evaluates log rules and posts to the same Alertmanager, so both arrive
through the same ntfy topic with the same formatting.

## Collection

### Scrape jobs

Global `scrape_interval` 15s, `retention` 30d (`modules/prometheus.nix`). Each
job is declared by the module that owns the thing being scraped, not centrally.

| Job | Target | Declared in | Covers |
|---|---|---|---|
| `prometheus` | `127.0.0.1:9090` | `prometheus.nix` | rule evaluation, TSDB health |
| `alertmanager` | `127.0.0.1:9093` | `alertmanager.nix` | notification delivery success/failure |
| `grafana` | `127.0.0.1:3000` | `grafana.nix` | dashboard server |
| `loki` | `127.0.0.1:3100` | `loki.nix` | log ingestion rates |
| `alloy` | `127.0.0.1:12345` | `hosts/thor/alloy.nix` | the log shipper itself |
| `blocky` | `127.0.0.1:4000` | `blocky.nix` | DNS queries, blocklists, cache |
| `node-exporter` | `thor:9100` | `hosts/thor/node-exporter.nix` | CPU, memory, filesystems, hwmon, **systemd unit states**, textfile |
| `zfs-exporter` | `thor:9134` | `hosts/thor/zfs-exporter.nix` | pool health, dataset usage |
| `smartctl-exporter` | `thor:9633` | `hosts/thor/smartctl-exporter.nix` | per-drive SMART attributes |
| `cadvisor` | `127.0.0.1:9338` | `hosts/thor/container-metrics.nix` | per-container CPU, memory, start time |
| `blackbox-exporter` | `127.0.0.1:9115` | `hosts/thor/blackbox-exporter.nix` | the prober itself |
| `blackbox-http` | every `monitoring.probeTargets` entry | `hosts/thor/blackbox-exporter.nix` | end-to-end HTTP reachability |

`node-exporter` runs the `systemd` collector, which is what makes
`node_systemd_unit_state` — and therefore per-unit failure alerting — possible
without parsing logs.

### HTTP probes

Services do not register themselves with the prober. They contribute a URL to
`monitoring.probeTargets` (declared in `modules/interfaces.nix`), and
`mkProxiedService` does it for them (`modules/lib/proxy.nix`). Two conventions
matter:

- **Keyed by display name.** The attribute key becomes the probe's `instance`
  label, so alerts read `Prowlarr`, not `http://127.0.0.1:9696`. The probed URL
  survives as a separate `target` label — set by a relabel rule that has to run
  *before* `__address__` is rewritten to the exporter.
- **`probePath` aims at a health endpoint** where one exists without an API key
  (`/api/health`, `/healthcheck`, `/v1/health`). Probing `/` only proves
  something is listening, which a service whose database won't open will
  happily keep doing — exactly the Bar Assistant failure.

Two services set `monitoring.probeTargets` directly rather than through
`mkProxiedService`: Bar Assistant, which needs subpath routing across three
backends and whose *API* is the component worth probing rather than its static
frontend; and Homepage, which is the dashboard the service tiles live on and so
has no tile of its own to generate.

Probes run every 60s, redirects followed, IPv4, 10s prober timeout inside a 15s
scrape timeout.

### Container health

cAdvisor reports resource usage and start times but not Docker's `HEALTHCHECK`
verdict, and node-exporter has no Docker collector. So
`hosts/thor/container-metrics.nix` runs a 30s timer that renders `docker
inspect` into the textfile collector at
`/var/lib/prometheus-node-exporter-textfile/docker-health.prom`:

| Metric | Meaning |
|---|---|
| `docker_container_running{name}` | 1 while the container runs; 0 when it exists but is stopped |
| `docker_container_health_status{name,status}` | 1 on the current state, 0 on the others; absent for images that declare no healthcheck |

Every health state is emitted rather than just the live one, so recovery
resolves on the next scrape instead of waiting ~5m for the old series to go
stale. If the Docker daemon is unreachable the script fails the unit rather
than publishing zeroes — that raises `SystemdUnitFailed`, and the frozen file
mtime raises `ContainerHealthCollectorStale`.

`docker_container_running` is the only signal covering containers started
outside Nix (via Portainer): they have no systemd unit, so nothing else watches
them. Nix-declared containers are covered by their unit instead — stopping one
runs `oci-containers`' post-stop hook, which `docker rm -f`s it, so it leaves
the metric set rather than lingering at 0.

### Logs

Alloy reads the systemd journal (12h max age) and pushes to Loki, relabelling
`unit`, `hostname` and `level` out of journal fields. Loki keeps 30 days.

Log rules live in `modules/loki.nix` and are written to
`/srv/loki/rules/fake/log-alerts.yml` (`fake` being the tenant when
`auth_enabled = false`). Note the `L+` tmpfiles rule there: plain `L` only
creates the symlink when the path is absent, so rule edits silently stop
deploying after the first build. That was a live bug.

## Alerting

Metric rules are in `modules/alert-rules.nix`, one YAML block, grouped. Log
rules are in `modules/loki.nix`. Both fire into Alertmanager.

### Metric alerts

| Group | Alert | Sev | Fires when |
|---|---|---|---|
| `host-health` | `HostHighCpuTemperature` | crit | CPU >80°C for 5m |
| | `HostHighCpuTemperatureWarn` | warn | CPU >72°C for 10m |
| | `HostMemoryAlmostFull` | crit | <10% available for 10m |
| | `HostMemoryHighUsage` | warn | <20% available for 15m |
| | `HostFilesystemAlmostFull` | crit | <10% free for 10m |
| | `HostFilesystemFillingUp` | warn | <20% free for 30m |
| | `MergerfsLowFreeSpace` | warn | pool <100 GiB free for 30m |
| | `HostFanStopped` | crit | chassis fan at 0 RPM for 2m |
| | `InstanceDown` | crit | a scrape target unreachable 5m (probes excluded) |
| `storage-health` | `ZfsPoolNotOnline` | crit | pool not ONLINE |
| | `SmartUnhealthy` | crit | drive declares overall SMART failure |
| | `SmartTemperatureHigh` | warn | drive >55°C for 10m |
| | `SmartSectorErrors` | warn | reallocated/pending/uncorrectable sectors non-zero — the early warning `SmartUnhealthy` is too late for |
| `dns-health` ([blocky.md](blocky.md)) | `BlockyResolutionErrors` | crit | resolution failing, usually Mullvad unreachable |
| | `BlockyListDownloadsFailing` | warn | blocklist downloads failing — Blocky keeps serving, so blocking degrades silently |
| | `BlockyListRefreshStale` | warn | lists >48h old |
| `probe-health` | `ProbeFailed` | crit | a service's HTTP probe fails 5m — unreachable, non-2xx, or hung while its unit stays active |
| | `ProbeSlow` | warn | probe >5s for 10m |
| `container-health` | `ContainerUnhealthy` | crit | Docker `HEALTHCHECK` failing 5m while the unit stays active |
| | `ContainerRestartLoop` | crit | >3 restarts in 15m |
| | `ContainerStopped` | warn | container still exists but hasn't run for 10m — in practice a non-Nix one, see [Container health](#container-health) |
| | `ContainerHealthCollectorStale` | warn | the health textfile is >10m old |
| `monitoring-health` | `MonitoringUnitDown` | crit | prometheus, alertmanager, alertmanager-ntfy, loki, grafana or alloy not active |
| | `SystemdUnitFailed` | crit | any unit in `failed` for 5m, named |
| | `AlertmanagerNotificationsFailing` | crit | the ntfy webhook has been erroring 5m |
| | `LogIngestionStopped` | crit | Loki received nothing for 15m — Alloy up but shipping nothing would silently disable every log rule |
| | `PrometheusRuleEvaluationFailures` | warn | a rule expression is broken |

### Log alerts

Evaluated by Loki's ruler every 1m over the journal.

| Alert | Sev | Fires when |
|---|---|---|
| `SystemdUnitCrashLooping` | crit | >2 "failed with result"/non-zero exits in 5m — catches `Restart=always` units that never settle into `failed` |
| `OomKill` | crit | the OOM killer ran |
| `ZfsKernelError` | crit | ZFS logged an error, degradation, fault or corruption |
| `KernelHardFault` | crit | kernel panic, hard lockup or machine check exception |
| `SystemdCoredump` | warn | systemd-coredump recorded a crash |

### Severity

`critical` means acting now; `warning` means headroom is shrinking. The
difference is not cosmetic — it drives repeat cadence, ntfy priority and
inhibition.

### Routing and delivery

`modules/alertmanager.nix`: grouped by `alertname` + `instance` + `severity`,
30s group wait, 5m group interval, repeat every 12h — or 4h for `critical`.
A firing `critical` inhibits a `warning` sharing the same alertname and
instance, so a filesystem crossing both thresholds pages once.

Delivery is a webhook to `alertmanager-ntfy` (`modules/alertmanager-ntfy.nix`),
which posts to `https://ntfy.greensroad.uk`:

| | |
|---|---|
| Priority | `urgent` for critical, `high` otherwise |
| Tags | 🚨 firing critical · ⚠️ firing warning · ✅ resolved |
| Title | `[Resolved] AlertName on instance` |
| Body | the alert's `summary`, then `description` |
| Topic | `thor` |

`send_resolved` is on, so every alert is followed by its recovery. The topic
is a plain string in the Nix store, not a secret: ntfy is only reachable
through the cloudflared tunnel and the tailnet, both already auth-gated, so
the topic name isn't what protects it.

## What catches what

The point of the whole arrangement. Each row is a way thor can fail and the
signal that turns it into a notification.

| Failure | Caught by |
|---|---|
| Unit exits and systemd gives up | `SystemdUnitFailed` (metrics, per-unit) |
| Unit crash-loops without settling | `SystemdUnitCrashLooping` (journal) |
| Monitoring component stops | `MonitoringUnitDown` |
| Exporter unreachable | `InstanceDown` |
| **App up but serving nothing** — process alive, port bound, requests failing | `ProbeFailed` against a health endpoint |
| App slow | `ProbeSlow` |
| **Container active but failing its healthcheck** | `ContainerUnhealthy` |
| Container restart-looping | `ContainerRestartLoop` |
| Container stopped and forgotten | `ContainerStopped` |
| Container deliberately removed | *nothing, by design* — the metrics leave with it |
| Host out of memory, disk, or cooling | `host-health` group |
| Drive degrading | `SmartSectorErrors` early, `SmartUnhealthy` late, `ZfsPoolNotOnline`, `ZfsKernelError` |
| Process OOM-killed | `OomKill` |
| Kernel panic / lockup / MCE | `KernelHardFault` |
| DNS broken or blocking degraded | `dns-health` group — see [blocky.md](blocky.md) |
| Alert delivery itself broken | `AlertmanagerNotificationsFailing`, `LogIngestionStopped`, `PrometheusRuleEvaluationFailures`, `ContainerHealthCollectorStale` |
| **thor down, unpowered, or off the network** | *nothing* — see [Deliberate omissions](#deliberate-omissions) |

The two bold rows are the failure classes that motivated issue #192: both leave
systemd perfectly happy.

## Dashboards

Provisioned read-only from `modules/dashboards/` — `node-exporter-full`,
`cadvisor`, `smartctl`, `storage-health`, `blackbox-http`, `blocky`,
`blocky-query`, `system-errors-warnings`. Each is contributed by the module
owning the metrics it displays. See [dashboards.md](dashboards.md).

## Runbook

This section debugs the monitoring pipeline itself. To debug the *service* an
alert is complaining about, see [troubleshooting.md](troubleshooting.md).

Only Grafana has a vhost (`grafana.greensroad.uk`, through the tunnel).
Prometheus binds `0.0.0.0:9090` but its port is not opened in the firewall, so
it is reachable from the tailnet and the host only. Alertmanager binds
`127.0.0.1:9093` — on thor itself, or over an SSH tunnel, and nowhere else.

```sh
# What is firing right now
curl -s 'localhost:9090/api/v1/query?query=ALERTS{alertstate="firing"}' \
  | jq -c '.data.result[].metric'

# Are all targets up?
curl -s localhost:9090/api/v1/targets \
  | jq -r '.data.activeTargets[] | select(.health!="up") | .labels.job, .lastError'

# Did the rules load?
curl -s localhost:9090/api/v1/rules | jq -r '.data.groups[].name'

# Container health, as published
sudo systemctl start docker-health-textfile.service
cat /var/lib/prometheus-node-exporter-textfile/docker-health.prom

# Probe one service by hand, as the prober sees it
curl -s 'localhost:9115/probe?module=http_2xx&target=http://127.0.0.1:3000/api/health' \
  | grep -E '^probe_(success|http_status_code|duration_seconds)'

# Log rules actually deployed (the symlink is the usual suspect)
sudo ls -l /srv/loki/rules/fake/
```

Silences are runtime state in Alertmanager, not config in this repo, so one
survives a rebuild but not a state wipe. From thor:

```sh
nix shell nixpkgs#prometheus-alertmanager -c amtool \
  --alertmanager.url http://127.0.0.1:9093 silence add \
  alertname=ContainerStopped name=soularr --duration 2h --comment "planned"
```

Adding things:

- **A probe** — nothing to do if the service uses `mkProxiedService`; set
  `probePath` if it has a health endpoint. Otherwise assign
  `monitoring.probeTargets."Display Name"` in the service's own module.
- **A rule** — `modules/alert-rules.nix` for metrics, `modules/loki.nix` for
  logs. `nix flake check` only proves the YAML is a string, so check the
  PromQL before rebuilding:

  ```sh
  nix eval --impure --raw .#nixosConfigurations.thor.config.services.prometheus.rules \
    --apply 'r: builtins.elemAt r 0' > /tmp/rules.yml
  nix shell nixpkgs#prometheus.cli -c promtool check rules /tmp/rules.yml
  ```

- **A dashboard** — see [dashboards.md](dashboards.md).

Alerts are best verified by causing one. Stopping a container trips
`ProbeFailed` at 5m and `ContainerStopped` at 10m, and starting it again should
produce two resolved notifications.

## Deliberate omissions

- **No off-host monitoring.** thor watches thor. If it loses power or network,
  nothing notifies — the alert pipeline dies with the host it monitors. Issue
  #132 tracks moving a copy of the stack onto a Raspberry Pi, which is the only
  real fix.
- **Homepage's `siteMonitor` tiles are dashboard-only.** They colour a tile and
  alert nobody. During the Bar Assistant incident the tile pinged the healthy
  frontend while the API was dead, and looked fine throughout. Blackbox probes
  exist because of this.
- **uptime-kuma and the nginx exporter were removed, not fixed** — the probes
  cover the first, and nothing consumed the second.
- **No per-container CPU/memory alerts.** No container has resource limits set,
  so any threshold would be invented rather than derived; host-level memory
  pressure and `OomKill` cover the outcome that matters.
- **No alerting on Grafana itself beyond liveness.** Grafana renders data it
  does not own; a Grafana outage costs visibility, not service.
