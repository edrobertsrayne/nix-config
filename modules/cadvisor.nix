{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  # Per-container metrics for a Docker host. The Docker health textfile
  # collector it pulls in lives in modules/docker-health.nix, shared with
  # njord.
  flake.modules.nixos.cadvisor = _: {
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

    monitoring.dashboards.cadvisor = ./dashboards/cadvisor.json;
  };
}
