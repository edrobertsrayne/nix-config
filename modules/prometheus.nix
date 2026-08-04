{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.prometheus = _: {
    services.prometheus = {
      enable = true;
      port = ports.prometheus;
      stateDir = "prometheus";
      globalConfig = {
        scrape_interval = "15s";
        evaluation_interval = "15s";
      };
      retentionTime = "30d";
      # Scrape configs and alertmanagers added by individual service modules
      scrapeConfigs = [
        {
          job_name = "prometheus";
          static_configs = [
            {
              targets = ["127.0.0.1:${toString ports.prometheus}"];
            }
          ];
        }
      ];
      alertmanagers = [];
    };

    services.grafana.provision.datasources.settings = {
      # Paired with the datasource below; see modules/grafana.nix for why.
      deleteDatasources = [
        {
          name = "Prometheus";
          orgId = 1;
        }
      ];

      datasources = [
        {
          name = "Prometheus";
          uid = "prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://thor:${toString ports.prometheus}";
          isDefault = true;
        }
      ];
    };
  };
}
