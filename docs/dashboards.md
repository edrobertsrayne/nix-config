# Grafana dashboards

The JSON lives in [`modules/dashboards/`](../modules/dashboards) and is
provisioned into Grafana by `modules/grafana.nix`. Each file is referenced from
the module that owns the metrics it displays, via `monitoring.dashboards.<stem>`
(declared in `modules/interfaces.nix`).

Provisioned dashboards are read-only in the browser (`allowUiUpdates = false`).
To change one, edit the JSON and rebuild. To design a panel interactively, build
it in a throwaway dashboard in the UI, then use Grafana's *Export → JSON* and
paste the result back into that directory.

## Datasource UIDs

Dashboards reference datasources by the uids pinned in `modules/grafana.nix`:
`prometheus`, `loki` and `blocky-postgres`. Do not use auto-generated uids —
they differ per install.

## Refreshing a community dashboard

Community dashboards are patched once, on download, and the patched result is
committed. Nothing is fetched at build or run time. To pull a newer revision:

```sh
ID=1860 REV=45 SLUG=node-exporter-full
curl -sf "https://grafana.com/api/dashboards/$ID/revisions/$REV/download" \
  | jq --arg slug "$SLUG" 'del(.__inputs, .__requires) | .id = null | .uid = $slug' \
  | sed -e 's/${DS_PROMETHEUS}/prometheus/g' \
        -e 's/"DS_PROMETHEUS"/"prometheus"/g' \
        -e 's/${DS_LOKI}/loki/g' \
  > "modules/dashboards/$SLUG.json"
```

Each step matters:

- **`del(.__inputs, .__requires)`** — `__inputs` is the block that produces the
  "select your datasource" prompt on UI import. File provisioning never fills it
  in, so leaving it means `${DS_PROMETHEUS}` survives into every panel and the
  dashboard loads with all panels erroring.
- **`.id = null`** — Grafana rejects a provisioned dashboard carrying a numeric
  id that collides with an existing one.
- **`.uid = $slug`** — a stable uid, so re-provisioning updates in place rather
  than creating duplicates.

Afterwards, check nothing was missed:

```sh
grep -oE 'DS_[A-Z_]+|VAR_[A-Z_]+' modules/dashboards/*.json
```

## Sources

| File | grafana.com | Revision |
|---|---|---|
| `node-exporter-full.json` | [1860](https://grafana.com/grafana/dashboards/1860) | 45 |
| `blocky.json` | [13768](https://grafana.com/grafana/dashboards/13768) | 8 |
| `blackbox-http.json` | [13659](https://grafana.com/grafana/dashboards/13659) | 1 |
| `cadvisor.json` | [14282](https://grafana.com/grafana/dashboards/14282) | 1 |
| `smartctl.json` | [20204](https://grafana.com/grafana/dashboards/20204) | 1 |
| `blocky-query.json` | [14980](https://grafana.com/grafana/dashboards/14980), rewritten | 1 |
| `system-errors-warnings.json` | hand-written | — |
| `storage-health.json` | hand-written | — |
| `host-comparison.json` | hand-written | — |

`blocky-query.json` is **not** a straight download. Upstream 14980 is written
for MySQL (`INSTR`, `SUBSTRING_INDEX`), but `queryLog.type` here is
`postgresql`, so every panel's `rawSql` was rewritten to postgres dialect
(`POSITION`, `SPLIT_PART`, `EXTRACT(EPOCH …)`). Refreshing it from grafana.com
would undo that — port the SQL by hand instead. It reads `log_entries` through
the `blocky-postgres` datasource; the `grafana` role and its `SELECT` grant are
declared in `modules/blocky.nix`.

`host-comparison.json` exists because `node-exporter-full.json` is single-host
and was deliberately left that way. Upstream 1860 pins every panel with exact
matchers — all **284** of its expressions carry both `instance="$node"` and
`job="$job"`, and none of its 231 legend formats mention `instance`. Making it
multi-host therefore means rewriting every matcher to `=~`, rewriting every
legend, and converting the 14 gauge/stat panels that reduce a series to a single
number and cannot show two hosts at once. That would fork a 468 KB vendored file
from upstream permanently, so each refresh would have to re-apply all of it.

The comparison dashboard covers the same ground in 8 hand-written panels
(scrape status, uptime, CPU, memory, load per core, filesystem, network in/out),
keyed on `job=~"node-exporter.*"` so any future host whose scrape job follows
that naming appears automatically, with no dashboard edit. Its `Host` variable
is `label_values(up{job=~"node-exporter.*"}, instance)`, so legends read
`thor:9100` / `mimir:9100` — the `instance` label, not the Loki `host` label
that `system-errors-warnings.json` uses. The two are deliberately not unified:
adding a `host` label to the scrape configs would change every existing metric's
series identity.

`smartctl.json` carries local fixes and is no longer upstream 20204 verbatim —
re-downloading it would undo them. "Power on Time" shipped with a hardcoded
`instance="192.168.1.7:9633"`, an address this network does not use (the
exporter is scraped as `thor:9633`), so the panel rendered "No data"
indefinitely; the selector was dropped, matching every other panel in the file.
Its two NVMe panels also hardcoded `device="nvme0"`, now `device=~"nvme.*"` so a
second drive appears instead of being silently ignored.

`system-errors-warnings.json` is multi-host. Its `Host` variable reads
`label_values({job="systemd-journal"}, host)`, so a new host shipping logs to
Loki appears in the dropdown with no dashboard edit. Both aggregating panels
group `by (host, …)` — dropping `host` from a `sum by` there would sum
same-named units (`sshd.service` on thor and on mimir) into one misleading
series, which is the bug the variable exists to prevent.

`blocky.json` also declared a `VAR_BLOCKY_URL` input, substituted with
`http://thor:4000` (`ports.blocky`). It is used by the "Blocking control" canvas
panel, which calls Blocky's API **from the browser** — so that panel works from
the tailnet (`tailscale0` is a trusted interface) but not over the Cloudflare
tunnel, where the browser cannot reach port 4000. Everything else on that
dashboard is served through Prometheus and works either way.
