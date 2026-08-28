{lib, ...}: {
  options.flake.settings.hosts = with lib; {
    thor = {
      address = mkOption {
        type = types.str;
        default = "192.168.68.128";
      };

      # nginx's proxyPass to mimir now resolves over tailscale0
      # (mimir.tailnetName below), so requests mimir sees from thor arrive on
      # this address, not thor.address. Already hardcoded in modules/blocky.nix.
      tailnetAddress = mkOption {
        type = types.str;
        default = "100.84.196.40";
      };
    };

    mimir = {
      address = mkOption {
        type = types.str;
        default = "192.168.68.129";
      };

      tailnetName = mkOption {
        type = types.str;
        default = "mimir";
      };

      # podman's port publishing (soularr.nix) DNATs by destination IP and
      # bypasses networking.firewall, so it needs the concrete tailnet address
      # to bind to - a hostname won't do here the way it does for proxyPass.
      tailnetAddress = mkOption {
        type = types.str;
        default = "100.84.179.61";
      };
    };
  };
}
