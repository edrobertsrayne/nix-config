{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.thor = _: {
    services.prometheus.scrapeConfigs = [
      {
        job_name = "node-exporter-njord";
        static_configs = [
          {
            targets = ["njord:${toString ports.exporters.node}"];
          }
        ];
      }
    ];
  };
}
