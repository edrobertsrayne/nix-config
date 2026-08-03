{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
in {
  flake.modules.nixos.grafana = {config, ...}: {
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
          datasources.settings.datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              access = "proxy";
              url = "http://thor:${toString ports.prometheus}";
              isDefault = true;
            }
            {
              name = "Loki";
              type = "loki";
              access = "proxy";
              url = "http://thor:${toString ports.loki}";
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
