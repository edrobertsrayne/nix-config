_: {
  flake.modules.nixos.prometheus = _: {
    services.prometheus.rules = [
      ''
        groups:
          - name: host-health
            rules:
              - alert: HostHighCpuTemperature
                expr: node_hwmon_temp_celsius{chip=~".*coretemp.*",sensor="temp1"} > 80
                for: 5m
                labels:
                  severity: critical
                annotations:
                  summary: CPU temperature critical on {{ $labels.instance }}
                  description: "CPU temp is {{ $value | printf \"%.1f\" }}°C (threshold: 80°C)"

              - alert: HostHighCpuTemperatureWarn
                expr: node_hwmon_temp_celsius{chip=~".*coretemp.*",sensor="temp1"} > 72
                for: 10m
                labels:
                  severity: warning
                annotations:
                  summary: CPU temperature elevated on {{ $labels.instance }}
                  description: "CPU temp is {{ $value | printf \"%.1f\" }}°C (threshold: 72°C)"

              - alert: HostMemoryAlmostFull
                expr: (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) < 0.10
                for: 10m
                labels:
                  severity: critical
                annotations:
                  summary: Memory critically low on {{ $labels.instance }}
                  description: "Only {{ $value | humanizePercentage }} memory available"

              - alert: HostMemoryHighUsage
                expr: (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) < 0.20
                for: 15m
                labels:
                  severity: warning
                annotations:
                  summary: Memory usage high on {{ $labels.instance }}
                  description: "Only {{ $value | humanizePercentage }} memory available"

              - alert: HostFilesystemAlmostFull
                expr: >
                  (node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|fuse\\.mergerfs"}
                  / node_filesystem_size_bytes{fstype!~"tmpfs|overlay|fuse\\.mergerfs"}) < 0.10
                for: 10m
                labels:
                  severity: critical
                annotations:
                  summary: Filesystem almost full on {{ $labels.instance }}
                  description: "{{ $labels.mountpoint }} has only {{ $value | humanizePercentage }} free ({{ $labels.fstype }})"

              - alert: HostFilesystemFillingUp
                expr: >
                  (node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|fuse\\.mergerfs"}
                  / node_filesystem_size_bytes{fstype!~"tmpfs|overlay|fuse\\.mergerfs"}) < 0.20
                for: 30m
                labels:
                  severity: warning
                annotations:
                  summary: Filesystem filling up on {{ $labels.instance }}
                  description: "{{ $labels.mountpoint }} has only {{ $value | humanizePercentage }} free ({{ $labels.fstype }})"

              - alert: MergerfsLowFreeSpace
                expr: node_filesystem_avail_bytes{fstype="fuse.mergerfs"} < 107374182400
                for: 30m
                labels:
                  severity: warning
                annotations:
                  summary: MergerFS pool low on free space on {{ $labels.instance }}
                  description: "{{ $labels.mountpoint }} has only {{ $value | humanize }}B free (threshold: 100 GiB)"

              - alert: HostFanStopped
                expr: node_hwmon_fan_rpm{chip=~"platform_it87.*",sensor="fan2"} == 0
                for: 2m
                labels:
                  severity: critical
                annotations:
                  summary: Fan stopped on {{ $labels.instance }}
                  description: "Fan {{ $labels.sensor }} ({{ $labels.chip }}) reports 0 RPM — possible fan failure"

              - alert: InstanceDown
                expr: up{job!="blackbox-http"} == 0
                for: 5m
                labels:
                  severity: critical
                annotations:
                  summary: Scrape target down — {{ $labels.job }} on {{ $labels.instance }}
                  description: "{{ $labels.instance }} (job={{ $labels.job }}) has been unreachable for >5m"

          - name: storage-health
            rules:
              - alert: ZfsPoolNotOnline
                expr: zfs_pool_health != 0
                for: 1m
                labels:
                  severity: critical
                annotations:
                  summary: ZFS pool degraded on {{ $labels.instance }}
                  description: "Pool {{ $labels.pool }} health code is {{ $value }} (0: ONLINE, 1: DEGRADED, 2: FAULTED, 3: OFFLINE, 4: UNAVAIL, 5: REMOVED, 6: SUSPENDED)"

              - alert: SmartUnhealthy
                expr: smartctl_device_smart_status != 1
                for: 1m
                labels:
                  severity: critical
                annotations:
                  summary: SMART health failure on {{ $labels.instance }}
                  description: "Drive {{ $labels.device }} reports SMART status unhealthy"

              - alert: SmartTemperatureHigh
                expr: smartctl_device_temperature > 55
                for: 10m
                labels:
                  severity: warning
                annotations:
                  summary: Drive temperature high on {{ $labels.instance }}
                  description: "Drive {{ $labels.device }} is {{ $value }}°C (threshold: 55°C)"

              # SmartUnhealthy only fires once a drive declares overall failure,
              # which is late. Reallocated (5), pending (197) and uncorrectable
              # (198) sector counts creep up first, so any non-zero value is worth
              # knowing about while the drive still reports itself healthy.
              - alert: SmartSectorErrors
                expr: smartctl_device_attribute{attribute_id=~"5|197|198",attribute_value_type="raw"} > 0
                for: 15m
                labels:
                  severity: warning
                annotations:
                  summary: SMART sector errors on {{ $labels.instance }}
                  description: "Drive {{ $labels.device }} reports {{ $value }} {{ $labels.attribute_name }} — reallocated or pending sectors indicate a drive beginning to fail"

          - name: dns-health
            rules:
              # Blocky resolves DNS for the whole network, so a failure here is
              # felt everywhere. loading.strategy = "fast" means Blocky serves
              # regardless of blocklist state, which makes the two list rules
              # necessary: without them, blocking degrades with no symptom.
              # Blocky retries 3x per query and has a Quad9 fallback upstream,
              # so a raw error count is never zero — it sits at a ~1%
              # background rate from normal DoH flakiness. Alert on a
              # sustained error *rate* instead, so this only fires when
              # resolution is actually degraded.
              - alert: BlockyResolutionErrors
                expr: >
                  (sum(increase(blocky_error_total[15m])) /
                   sum(increase(blocky_query_total[15m]))) > 0.1
                for: 15m
                labels:
                  severity: critical
                annotations:
                  summary: Blocky resolution errors on {{ $labels.instance }}
                  description: "Blocky's error rate is {{ $value | humanizePercentage }} over the last 15m — the upstream DoH resolver(s) may be unreachable"

              - alert: BlockyListDownloadsFailing
                expr: increase(blocky_failed_downloads_total[1h]) > 0
                for: 15m
                labels:
                  severity: warning
                annotations:
                  summary: Blocky blocklist downloads failing on {{ $labels.instance }}
                  description: "{{ $value }} blocklist download(s) failed in the last hour — Blocky keeps serving, so ad/tracker blocking degrades silently"

              - alert: BlockyListRefreshStale
                expr: time() - blocky_last_list_group_refresh_timestamp_seconds > 172800
                for: 30m
                labels:
                  severity: warning
                annotations:
                  summary: Blocky blocklists not refreshing on {{ $labels.instance }}
                  description: "Blocklists last refreshed {{ $value | humanizeDuration }} ago (threshold: 48h) — blocking is running on stale data"

          - name: monitoring-health
            rules:
              - alert: MonitoringUnitDown
                expr: >
                  node_systemd_unit_state{name=~"(prometheus|alertmanager|alertmanager-ntfy|loki|grafana|alloy)\\.service",state="active"} != 1
                for: 5m
                labels:
                  severity: critical
                annotations:
                  summary: Monitoring component down on {{ $labels.instance }}
                  description: "{{ $labels.name }} is not active — alerting or log/metric collection may be degraded"

              - alert: SystemdUnitFailed
                expr: node_systemd_unit_state{state="failed"} == 1
                for: 5m
                labels:
                  severity: critical
                annotations:
                  summary: Systemd unit failed on {{ $labels.instance }}
                  description: "{{ $labels.name }} has been in a failed state for >5m — check systemctl --failed"

              - alert: AlertmanagerNotificationsFailing
                expr: sum(rate(alertmanager_notifications_failed_total{integration="webhook"}[15m])) > 0
                for: 5m
                labels:
                  severity: critical
                annotations:
                  summary: Alertmanager notification delivery failing on {{ $labels.instance }}
                  description: "The ntfy webhook has been failing for >5m — alert delivery may be silently broken"

              - alert: LogIngestionStopped
                expr: sum(rate(loki_distributor_lines_received_total[15m])) == 0
                for: 15m
                labels:
                  severity: critical
                annotations:
                  summary: Log ingestion stopped on {{ $labels.instance }}
                  description: "Loki has received no log lines for >15m — Alloy may be running but shipping nothing, silently disabling the log-alerts rule group"

              - alert: PrometheusRuleEvaluationFailures
                expr: increase(prometheus_rule_evaluation_failures_total[15m]) > 0
                for: 5m
                labels:
                  severity: warning
                annotations:
                  summary: Prometheus rule evaluation failing on {{ $labels.instance }}
                  description: "A rule has failed to evaluate in the last 15m — check prometheus logs for the broken expression"

          - name: probe-health
            rules:
              # instance is the service's display name and target is the exact
              # URL probed, so these read as "Prowlarr" rather than
              # "http://127.0.0.1:9696" without losing the endpoint.
              - alert: ProbeFailed
                expr: probe_success == 0
                for: 5m
                labels:
                  severity: critical
                annotations:
                  summary: HTTP probe failing — {{ $labels.instance }}
                  description: "{{ $labels.instance }} has failed its blackbox probe of {{ $labels.target }} for >5m — unreachable, non-2xx, or hung while its unit stays active"

              - alert: ProbeSlow
                expr: probe_duration_seconds > 5
                for: 10m
                labels:
                  severity: warning
                annotations:
                  summary: HTTP probe slow — {{ $labels.instance }}
                  description: "{{ $labels.instance }} took {{ $value | printf \"%.1f\" }}s to respond to {{ $labels.target }} (threshold: 5s)"

          - name: container-health
            rules:
              # A container is "active" to systemd whenever its main process
              # runs, so none of these failures reach SystemdUnitFailed.
              - alert: ContainerUnhealthy
                expr: docker_container_health_status{status="unhealthy"} == 1
                for: 5m
                labels:
                  severity: critical
                annotations:
                  summary: Container unhealthy — {{ $labels.name }}
                  description: "{{ $labels.name }} has failed its Docker HEALTHCHECK for >5m while its unit stays active"

              # cAdvisor labels every cgroup, but only containers carry a name.
              - alert: ContainerRestartLoop
                expr: changes(container_start_time_seconds{name=~".+"}[15m]) > 3
                for: 5m
                labels:
                  severity: critical
                annotations:
                  summary: Container restart-looping — {{ $labels.name }}
                  description: "{{ $labels.name }} ({{ $labels.image }}) has restarted {{ $value }} times in 15m"

              # A container that is deliberately removed leaves the metric set
              # and stays quiet; one stopped and forgotten keeps nagging. 10m
              # rides out the restarts a rebuild causes.
              - alert: ContainerStopped
                expr: docker_container_running == 0
                for: 10m
                labels:
                  severity: warning
                annotations:
                  summary: Container stopped — {{ $labels.name }}
                  description: "{{ $labels.name }} still exists but has not been running for >10m"

              # Without this the collector could die and take the two Docker
              # rules above with it, silently — no series, no alert.
              - alert: ContainerHealthCollectorStale
                expr: time() - node_textfile_mtime_seconds{file=~".*/docker-health\\.prom"} > 600
                for: 5m
                labels:
                  severity: warning
                annotations:
                  summary: Container health metrics stale on {{ $labels.instance }}
                  description: "docker-health-textfile last wrote {{ $value | humanizeDuration }} ago (threshold: 10m) — container health and running state are no longer being reported"
      ''
    ];
  };
}
