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
          # Datasources are contributed by the module that runs the thing
          # being queried — prometheus.nix, loki.nix, blocky.nix — by adding
          # to services.grafana.provision.datasources.settings, the same way
          # scrape jobs are contributed to prometheus. Both lists here are
          # plain listOf, so the definitions concatenate.
          #
          # Two conventions those modules follow. uids are pinned, so the
          # dashboard JSON in modules/dashboards can reference a datasource by
          # a name we control rather than the random uid Grafana would
          # generate per install. And every datasource pairs with a
          # deleteDatasources entry for its own name: Grafana looks an
          # existing datasource up by uid, so pinning a uid onto one that was
          # created with a generated uid fails with "data source not found",
          # which aborts the whole provisioning module — dashboards included —
          # and crash-loops the service. Deleting first makes provisioning
          # authoritative and the startup idempotent.

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
