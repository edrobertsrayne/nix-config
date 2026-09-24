{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.njord = _: {
    services.prometheus.exporters.node = {
      enable = true;
      port = ports.exporters.node;
      enabledCollectors = [
        "systemd"
        "processes"
        "filesystem"
      ];
      # Restart=always units never reach the "failed" state SystemdUnitFailed
      # (modules/alert-rules.nix) watches for, so a crash-looping service can
      # go unnoticed indefinitely — as flaresolverr did for 2.5 days (#225).
      # Off by default; exposes node_systemd_service_restart_total.
      extraFlags = ["--collector.systemd.enable-restarts-metrics"];
    };
  };
}
