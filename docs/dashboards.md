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

`blocky-query.json` is **not** a straight download. Upstream 14980 is written
for MySQL (`INSTR`, `SUBSTRING_INDEX`), but `queryLog.type` here is
`postgresql`, so every panel's `rawSql` was rewritten to postgres dialect
(`POSITION`, `SPLIT_PART`, `EXTRACT(EPOCH …)`). Refreshing it from grafana.com
would undo that — port the SQL by hand instead. It reads `log_entries` through
the `blocky-postgres` datasource; the `grafana` role and its `SELECT` grant are
declared in `modules/blocky.nix`.

`blocky.json` also declared a `VAR_BLOCKY_URL` input, substituted with
`http://thor:4000` (`ports.blocky`). It is used by the "Blocking control" canvas
panel, which calls Blocky's API **from the browser** — so that panel works from
the tailnet (`tailscale0` is a trusted interface) but not over the Cloudflare
tunnel, where the browser cannot reach port 4000. Everything else on that
dashboard is served through Prometheus and works either way.
