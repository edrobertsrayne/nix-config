{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.mimir = _: {
    services.prometheus.exporters.node = {
      enable = true;
      port = ports.exporters.node;
      enabledCollectors = [
        "systemd"
        "processes"
        "filesystem"
      ];
    };
  };
}
