{
  inputs,
  lib,
  ...
}: let
  inherit (inputs.self.settings) ports hosts;
in {
  # One aspect for every host. The host running Prometheus also gets a
  # scrape job per host in settings.hosts, so adding a host there is all it
  # takes to have it scraped.
  flake.modules.nixos.node-exporter = {config, ...}: {
    services.prometheus = {
      exporters.node = {
        enable = true;
        port = ports.exporters.node;
        enabledCollectors = [
          "systemd"
          "processes"
          "filesystem"
        ];
        # Restart=always units never reach the "failed" state SystemdUnitFailed
        # watches for, so a crash-looping service can go unnoticed indefinitely.
        # Off by default; exposes node_systemd_service_restart_total.
        extraFlags = ["--collector.systemd.enable-restarts-metrics"];
      };

      # The local host keeps the bare job name the dashboards and alerts were
      # written against; every other host is node-exporter-<host>.
      scrapeConfigs = lib.mkIf config.services.prometheus.enable (map (host: {
        job_name =
          if host == config.networking.hostName
          then "node-exporter"
          else "node-exporter-${host}";
        static_configs = [
          {
            targets = ["${host}:${toString ports.exporters.node}"];
          }
        ];
      }) (builtins.attrNames hosts));
    };

    monitoring.dashboards = {
      node-exporter-full = ./dashboards/node-exporter-full.json;

      # Deliberately not part of node-exporter-full: that dashboard is vendored
      # from grafana.com (1860) and shows one host at a time, and making it
      # multi-host would mean rewriting ~284 expressions, forking it from
      # upstream permanently. This is the small hand-written counterpart that
      # answers "which host is unhappy" before you go there to find out why.
      host-comparison = ./dashboards/host-comparison.json;
    };
  };
}
