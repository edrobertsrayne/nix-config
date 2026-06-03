{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.loki = {pkgs, ...}: let
    logAlertRules = pkgs.writeText "log-alerts.yml" ''
      groups:
        - name: log-alerts
          interval: 1m
          rules:
            - alert: SystemdUnitFailed
              expr: |
                sum by (unit, host) (
                  count_over_time(
                    {job="systemd-journal"} |~ "(?i)failed with result|main process exited, code=exited, status=[^0]" [5m]
                  )
                ) > 0
              labels:
                severity: critical
              annotations:
                summary: Systemd unit failed on {{ $labels.host }}
                description: "Unit {{ $labels.unit }} reported a failure"

            - alert: OomKill
              expr: |
                sum by (host) (
                  count_over_time(
                    {job="systemd-journal"} |~ "(?i)out of memory|oom-killer|killed process" [5m]
                  )
                ) > 0
              labels:
                severity: critical
              annotations:
                summary: OOM kill detected on {{ $labels.host }}
                description: "A process was killed by the OOM killer"

            - alert: ZfsKernelError
              expr: |
                sum by (host) (
                  count_over_time(
                    {job="systemd-journal"} |~ "ZFS:" |~ "(?i)error|degraded|fault|corrupt" [10m]
                  )
                ) > 0
              labels:
                severity: critical
              annotations:
                summary: ZFS kernel error on {{ $labels.host }}
                description: "ZFS reported an error in the kernel log"

            - alert: KernelHardFault
              expr: |
                sum by (host) (
                  count_over_time(
                    {job="systemd-journal"} |~ "(?i)kernel panic|hard lockup|machine check exception|general protection fault" [5m]
                  )
                ) > 0
              labels:
                severity: critical
              annotations:
                summary: Kernel hard fault on {{ $labels.host }}
                description: "Kernel panic, hard lockup, or machine check exception detected"

            - alert: SystemdCoredump
              expr: |
                sum by (host) (
                  count_over_time({unit=~"systemd-coredump.*"} [10m])
                ) > 0
              labels:
                severity: warning
              annotations:
                summary: Process coredump on {{ $labels.host }}
                description: "systemd-coredump recorded a crash"
    '';
  in {
    services.loki = {
      enable = true;
      dataDir = "/srv/loki";
      configuration = {
        server.http_listen_port = ports.loki;
        auth_enabled = false;

        ingester = {
          lifecycler = {
            address = "127.0.0.1";
            ring = {
              kvstore.store = "inmemory";
              replication_factor = 1;
            };
            final_sleep = "0s";
          };
          chunk_idle_period = "1h";
          max_chunk_age = "1h";
          chunk_target_size = 999999;
          chunk_retain_period = "30s";
        };

        schema_config.configs = [
          {
            from = "2024-01-01";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];

        storage_config = {
          tsdb_shipper = {
            active_index_directory = "/srv/loki/tsdb-index";
            cache_location = "/srv/loki/tsdb-cache";
          };
          filesystem.directory = "/srv/loki/chunks";
        };

        limits_config = {
          reject_old_samples = true;
          reject_old_samples_max_age = "720h"; # 30 days
          retention_period = "720h"; # 30 days
        };

        table_manager = {
          retention_deletes_enabled = true;
          retention_period = "720h"; # 30 days
        };

        compactor = {
          working_directory = "/srv/loki/compactor";
          compaction_interval = "10m";
          retention_enabled = true;
          retention_delete_delay = "2h";
          retention_delete_worker_count = 150;
          delete_request_store = "filesystem";
        };

        ruler = {
          storage = {
            type = "local";
            local.directory = "/srv/loki/rules";
          };
          rule_path = "/srv/loki/rules-temp";
          alertmanager_url = "http://127.0.0.1:${toString ports.alertmanager}";
          ring.kvstore.store = "inmemory";
          enable_api = true;
        };
      };
    };

    # Loki local ruler expects rules at <storage.local.directory>/<tenant>/<file>.yml
    # With auth_enabled=false the tenant is "fake"
    systemd.tmpfiles.rules = [
      "d /srv/loki/rules 0750 loki loki -"
      "d /srv/loki/rules/fake 0750 loki loki -"
      "d /srv/loki/rules-temp 0750 loki loki -"
      "L /srv/loki/rules/fake/log-alerts.yml - - - - ${logAlertRules}"
    ];
  };
}
