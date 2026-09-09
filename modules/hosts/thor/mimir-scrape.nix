{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.thor = _: {
    services.prometheus.scrapeConfigs = [
      {
        job_name = "node-exporter-mimir";
        static_configs = [
          {
            targets = ["mimir:${toString ports.exporters.node}"];
          }
        ];
      }
    ];
  };
}
