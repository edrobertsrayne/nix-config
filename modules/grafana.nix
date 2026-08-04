{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
in {
  flake.modules.nixos.grafana = {
    config,
    lib,
    pkgs,
    ...
  }: {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Grafana";
        subdomain = "grafana";
        port = ports.grafana;
        group = "Infrastructure";
        description = "Metrics dashboard";
        icon = "grafana.png";
      })
    ];

    age.secrets.grafana = {
      file = ../secrets/grafana.age;
      owner = "grafana";
      group = "grafana";
    };

    services = {
      grafana = {
        enable = true;
        settings = {
          server = {
            http_port = ports.grafana;
            domain = "grafana.${server.domain}";
            root_url = "https://grafana.${server.domain}";
          };
          security.secret_key = "$__file{${config.age.secrets.grafana.path}}";
          analytics.reporting_enabled = false;
        };
        dataDir = "/srv/grafana";
        provision = {
          enable = true;
          # uids are pinned so the dashboard JSON in modules/dashboards can
          # reference them by a name we control. Grafana would otherwise
          # generate a random uid per install, which nothing can hardcode.
          #
          # deleteDatasources is required, not cosmetic: Grafana looks an
          # existing datasource up by uid, and pinning a uid onto one that was
          # created with a generated uid fails with "data source not found".
          # That failure aborts the whole provisioning module — dashboards
          # included — and crash-loops the service. Deleting first makes
          # provisioning authoritative and the startup idempotent.
          datasources.settings.deleteDatasources = [
            {
              name = "Prometheus";
              orgId = 1;
            }
            {
              name = "Loki";
              orgId = 1;
            }
            {
              name = "Blocky";
              orgId = 1;
            }
          ];

          datasources.settings.datasources = [
            {
              name = "Prometheus";
              uid = "prometheus";
              type = "prometheus";
              access = "proxy";
              url = "http://thor:${toString ports.prometheus}";
              isDefault = true;
            }
            {
              name = "Loki";
              uid = "loki";
              type = "loki";
              access = "proxy";
              url = "http://thor:${toString ports.loki}";
            }
            # Blocky's query log. The url is a socket directory, not a host:
            # Grafana's postgres driver treats a leading / as a unix socket
            # and authenticates by peer, so no secret is needed. The grafana
            # role and its SELECT grant are declared in modules/blocky.nix.
            {
              name = "Blocky";
              uid = "blocky-postgres";
              type = "postgres";
              access = "proxy";
              url = "/run/postgresql";
              user = "grafana";
              jsonData = {
                database = "blocky";
                sslmode = "disable";
                postgresVersion = 1600;
              };
            }
          ];

          # Dashboards are contributed by the module owning the metrics they
          # display (monitoring.dashboards in modules/interfaces.nix) and
          # collected into one directory here. allowUiUpdates = false makes
          # them read-only in the browser: edits go through the repo.
          dashboards.settings.providers = [
            {
              name = "home-server";
              type = "file";
              folder = "Home Server";
              allowUiUpdates = false;
              disableDeletion = true;
              options.path = pkgs.linkFarm "grafana-dashboards" (
                lib.mapAttrsToList (name: path: {
                  name = "${name}.json";
                  inherit path;
                })
                config.monitoring.dashboards
              );
            }
          ];
        };
      };

      prometheus.scrapeConfigs = [
        {
          job_name = "grafana";
          static_configs = [
            {
              targets = ["127.0.0.1:${toString ports.grafana}"];
            }
          ];
        }
      ];
    };
  };
}
