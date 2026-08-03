{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.thor = _: {
    services.cadvisor = {
      enable = true;
      port = ports.exporters.cadvisor;
    };

    monitoring.dashboards.cadvisor = ../../dashboards/cadvisor.json;
  };

  flake.modules.nixos.prometheus = _: {
    services.prometheus.scrapeConfigs = [
      {
        job_name = "cadvisor";
        static_configs = [
          {
            targets = ["127.0.0.1:${toString ports.exporters.cadvisor}"];
          }
        ];
      }
    ];
  };
}
