# Refreshing a community dashboard

Community dashboards (e.g. `node-exporter-full`, grafana.com 1860) are patched
once on download and committed. Nothing is fetched at build or run time.

```sh
ID=1860 REV=45 SLUG=node-exporter-full
curl -sf "https://grafana.com/api/dashboards/$ID/revisions/$REV/download" \
  | jq --arg slug "$SLUG" 'del(.__inputs, .__requires) | .id = null | .uid = $slug' \
  | sed -e 's/${DS_PROMETHEUS}/prometheus/g' \
        -e 's/"DS_PROMETHEUS"/"prometheus"/g' \
        -e 's/${DS_LOKI}/loki/g' \
  > "modules/dashboards/$SLUG.json"
```

- `__inputs` is the UI-import datasource prompt. File provisioning never fills
  it, so `${DS_PROMETHEUS}` would survive and every panel would error.
- `.id = null`: Grafana rejects a provisioned dashboard whose numeric id
  collides with an existing one.
- `.uid = $slug`: a stable uid, so re-provisioning updates in place.

Then check that no placeholder is left:

```sh
grep -oE 'DS_[A-Z_]+|VAR_[A-Z_]+' modules/dashboards/*.json
```
