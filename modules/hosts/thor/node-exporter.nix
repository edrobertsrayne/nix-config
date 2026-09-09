{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.thor = _: {
    services.prometheus.exporters.node = {
      enable = true;
      port = ports.exporters.node;
      enabledCollectors = [
        "systemd"
        "processes"
        "filesystem"
        "thermal_zone"
      ];
    };

    services.prometheus.scrapeConfigs = [
      {
        job_name = "node-exporter";
        static_configs = [
          {
            targets = ["thor:${toString ports.exporters.node}"];
          }
        ];
      }
    ];

    monitoring.dashboards.node-exporter-full = ../../dashboards/node-exporter-full.json;

    # Deliberately not part of node-exporter-full: that dashboard is vendored
    # from grafana.com (1860) and shows one host at a time, and making it
    # multi-host would mean rewriting ~284 expressions, forking it from
    # upstream permanently. This is the small hand-written counterpart that
    # answers "which host is unhappy" before you go there to find out why.
    monitoring.dashboards.host-comparison = ../../dashboards/host-comparison.json;
  };
}
