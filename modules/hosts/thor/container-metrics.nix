{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  # The Docker health textfile collector lives in modules/docker-health.nix,
  # shared with njord.
  flake.modules.nixos.thor = _: {
    imports = [inputs.self.modules.nixos.docker-health];

    services = {
      cadvisor = {
        enable = true;
        port = ports.exporters.cadvisor;
      };

      prometheus.scrapeConfigs = [
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

    monitoring.dashboards.cadvisor = ../../dashboards/cadvisor.json;
  };
}
