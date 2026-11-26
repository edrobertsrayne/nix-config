{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.blackbox-exporter = {
    config,
    lib,
    pkgs,
    ...
  }: let
    # Not monitoring.probeTargets: that option is HTTP-only and feeds ProbeFailed.
    # Router vs. the two public resolvers separates a LAN fault from an ISP one.
    icmpTargets = {
      Router = inputs.self.settings.network.gateway;
      Cloudflare = "1.1.1.1";
      Google = "8.8.8.8";
    };
  in {
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
          icmp:
            prober: icmp
            timeout: 5s
            icmp:
              preferred_ip_protocol: ip4
      '';
    };

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
        static_configs =
          lib.mapAttrsToList (name: url: {
            targets = [url];
            # Prometheus only derives instance from __address__ when nothing
            # else has set it, so this survives the rewrite below.
            labels.instance = name;
          })
          config.monitoring.probeTargets;
        relabel_configs = [
          {
            source_labels = ["__address__"];
            target_label = "__param_target";
          }
          # instance is the service name now, so keep the probed URL as its own
          # label — alerts still need to name the endpoint that failed. Has to
          # come before __address__ is rewritten to the exporter.
          {
            source_labels = ["__address__"];
            target_label = "target";
          }
          {
            target_label = "__address__";
            replacement = "127.0.0.1:${toString ports.exporters.blackbox}";
          }
        ];
      }
      {
        job_name = "blackbox-icmp";
        scrape_interval = "30s";
        scrape_timeout = "10s";
        metrics_path = "/probe";
        params.module = ["icmp"];
        static_configs =
          lib.mapAttrsToList (name: ip: {
            targets = [ip];
            labels.instance = name;
          })
          icmpTargets;
        relabel_configs = [
          {
            source_labels = ["__address__"];
            target_label = "__param_target";
          }
          {
            source_labels = ["__address__"];
            target_label = "target";
          }
          {
            target_label = "__address__";
            replacement = "127.0.0.1:${toString ports.exporters.blackbox}";
          }
        ];
      }
    ];

    monitoring.dashboards.blackbox-http = ./dashboards/blackbox-http.json;
  };
}
