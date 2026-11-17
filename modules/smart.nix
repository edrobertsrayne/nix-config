{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  # Drive health: smartd keeps the SMART attributes fresh, smartctl-exporter
  # publishes them, and modules/alert-rules.nix alerts on them.
  flake.modules.nixos.smart = _: {
    services = {
      # Kept for the drive-side work, not for notification: smartd enables
      # offline data collection and attribute autosave, which is what keeps the
      # SMART attributes fresh that smartctl-exporter reads and SmartSectorErrors
      # alerts on. Its own notification paths are deliberately unused — thor is
      # headless, so wall messages have no reader; alerting goes via Prometheus.
      smartd = {
        enable = true;
        autodetect = true;
        notifications.test = false;
      };

      prometheus = {
        exporters.smartctl = {
          enable = true;
          port = ports.exporters.smartctl;
        };

        scrapeConfigs = [
          {
            job_name = "smartctl-exporter";
            static_configs = [
              {
                targets = ["thor:${toString ports.exporters.smartctl}"];
              }
            ];
          }
        ];
      };
    };

    monitoring.dashboards.smartctl = ./dashboards/smartctl.json;
  };
}
