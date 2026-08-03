_: {
  flake.modules.nixos.prometheus = _: {
    services.prometheus.rules = [
      ''
        groups:
          - name: host-health
            rules:
              - alert: HostHighCpuTemperature
                expr: node_hwmon_temp_celsius{chip=~"coretemp.*",sensor="temp1"} > 80
                for: 5m
                labels:
                  severity: critical
                annotations:
                  summary: CPU temperature critical on {{ $labels.instance }}
                  description: "CPU temp is {{ $value | printf \"%.1f\" }}°C (threshold: 80°C)"

              - alert: HostHighCpuTemperatureWarn
                expr: node_hwmon_temp_celsius{chip=~"coretemp.*",sensor="temp1"} > 72
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
                expr: up == 0
                for: 5m
                labels:
                  severity: critical
                annotations:
                  summary: Scrape target down — {{ $labels.job }} on {{ $labels.instance }}
                  description: "{{ $labels.instance }} (job={{ $labels.job }}) has been unreachable for >5m"

          - name: storage-health
            rules:
              - alert: ZfsPoolNotOnline
                expr: zfs_pool_state{state!="online"} > 0
                for: 1m
                labels:
                  severity: critical
                annotations:
                  summary: ZFS pool degraded on {{ $labels.instance }}
                  description: "Pool {{ $labels.pool }} is in state {{ $labels.state }}"

              - alert: ZfsPoolErrorsIncreasing
                expr: >
                  increase(zfs_pool_read_errors_total[1h]) > 0
                  or increase(zfs_pool_write_errors_total[1h]) > 0
                  or increase(zfs_pool_checksum_errors_total[1h]) > 0
                for: 0m
                labels:
                  severity: critical
                annotations:
                  summary: ZFS pool errors detected on {{ $labels.instance }}
                  description: "Pool {{ $labels.pool }} has increasing I/O or checksum errors"

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
      ''
    ];
  };
}
