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
  };
}
