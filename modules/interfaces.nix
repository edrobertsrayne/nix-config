_: {
  # Cross-aspect option declarations. Always present in every nixosConfiguration
  # (wired into the base module list in modules/lib/hosts.nix) so that service
  # aspects can write to these options without depending on the consuming
  # aspect being imported.
  flake.modules.nixos.interfaces = {lib, ...}: {
    options.homepage.services = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.attrs);
      default = {};
      description = "Service tiles keyed by group name; each service module appends its entry here.";
    };

    options.monitoring.probeTargets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "HTTP URLs probed by blackbox-exporter; each proxied service appends its backend URL here.";
    };
  };
}
