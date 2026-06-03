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
      scrapeConfigs = [];
      alertmanagers = [];
    };
  };
}
