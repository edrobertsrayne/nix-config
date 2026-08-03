{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.thor = {pkgs, ...}: {
    services.prometheus.exporters.blackbox = {
      enable = true;
      port = ports.exporters.blackbox;
      listenAddress = "127.0.0.1";
      configFile = pkgs.writeText "blackbox.yml" ''
        modules:
          http_2xx:
            prober: http
            timeout: 10s
            http:
              method: GET
              follow_redirects: true
              preferred_ip_protocol: ip4
      '';
    };

    monitoring.dashboards.blackbox-http = ../../dashboards/blackbox-http.json;
  };

  flake.modules.nixos.prometheus = {config, ...}: {
    services.prometheus.scrapeConfigs = [
      {
        job_name = "blackbox-exporter";
        static_configs = [
          {
            targets = ["127.0.0.1:${toString ports.exporters.blackbox}"];
          }
        ];
      }
      {
        job_name = "blackbox-http";
        scrape_interval = "60s";
        scrape_timeout = "15s";
        metrics_path = "/probe";
        params.module = ["http_2xx"];
        static_configs = [
          {
            targets = config.monitoring.probeTargets;
          }
        ];
        relabel_configs = [
          {
            source_labels = ["__address__"];
            target_label = "__param_target";
          }
          {
            source_labels = ["__param_target"];
            target_label = "instance";
          }
          {
            target_label = "__address__";
            replacement = "127.0.0.1:${toString ports.exporters.blackbox}";
          }
        ];
      }
    ];
  };
}
