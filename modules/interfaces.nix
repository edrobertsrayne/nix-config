_: {
  # Cross-aspect option declarations. Always present in every nixosConfiguration
  # (wired into the base module list in modules/lib/hosts.nix) so that service
  # aspects can write to these options without depending on the consuming
  # aspect being imported.
  flake.modules.nixos.interfaces = {lib, ...}: {
    options = {
      homepage.services = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.attrs);
        default = {};
        description = "Service tiles keyed by group name; each service module appends its entry here.";
      };

      monitoring = {
        probeTargets = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {};
          description = "HTTP URLs probed by blackbox-exporter, keyed by the display name that becomes each probe's instance label.";
        };

        dashboards = lib.mkOption {
          type = lib.types.attrsOf lib.types.path;
          default = {};
          description = "Grafana dashboard JSON keyed by filename stem; each module appends the dashboard for the metrics it owns.";
        };
      };
    };
  };
}
