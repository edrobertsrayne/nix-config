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
        probePath = "/api/health";
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
          # Datasources are declared by the aspect that runs the thing queried,
          # as plain listOf definitions that concatenate. uids are pinned so
          # dashboard JSON can reference them by a name we control. Each
          # datasource pairs with a deleteDatasources entry for its own name:
          # Grafana looks datasources up by uid, so pinning a uid onto one
          # created with a generated uid fails with "data source not found",
          # aborting provisioning and crash-looping the service.

          # Dashboards are contributed by the module owning the metrics they
          # display (monitoring.dashboards) and are read-only in the browser:
          # edits go through the repo. Vendored community dashboards:
          # docs/grafana-dashboards.md.
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
