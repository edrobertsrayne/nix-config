{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.thor = _: {
    services.prometheus.exporters.zfs = {
      enable = true;
      port = ports.exporters.zfs;
    };

    services.prometheus.scrapeConfigs = [
      {
        job_name = "zfs-exporter";
        static_configs = [
          {
            targets = ["thor:${toString ports.exporters.zfs}"];
          }
        ];
      }
    ];

    # Spans ZFS, MergerFS and SMART; filed here as the primary owner.
    monitoring.dashboards.storage-health = ../../dashboards/storage-health.json;
  };
}
