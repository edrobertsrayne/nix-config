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

          - name: probe-health
            rules:
              - alert: ProbeFailed
                expr: probe_success == 0
                for: 5m
                labels:
                  severity: critical
                annotations:
                  summary: HTTP probe failing — {{ $labels.instance }}
                  description: "{{ $labels.instance }} has failed its blackbox HTTP probe for >5m — unreachable, non-2xx, or hung while its unit stays active"

              - alert: ProbeSlow
                expr: probe_duration_seconds > 5
                for: 10m
                labels:
                  severity: warning
                annotations:
                  summary: HTTP probe slow — {{ $labels.instance }}
                  description: "{{ $labels.instance }} took {{ $value | printf \"%.1f\" }}s to respond (threshold: 5s)"
      ''
    ];
  };
}
