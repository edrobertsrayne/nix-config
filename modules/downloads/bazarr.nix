{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.bazarr = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.bazarr;
  in {
    users.users.${cfg.user}.extraGroups = ["tank"];
    systemd.services.bazarr.serviceConfig.UMask = lib.mkForce "0002";
    services.bazarr = {
      enable = true;
      listenPort = ports.media.bazarr;
      dataDir = "/srv/bazarr";
    };
  };

  # See docs/deploying.md, "Same-host vs. cross-host services", for why this module exists.
  flake.modules.nixos.bazarr-proxy = inputs.self.lib.mkProxiedService {
    name = "Bazarr";
    subdomain = "bazarr";
    port = ports.media.bazarr;
    group = "Media";
    description = "Subtitle manager";
    icon = "bazarr.png";
    # This module sets no probePath. /api/system/status needs X-API-KEY, and
    # this key cannot go in the blackbox config, a world-readable store path.
    # The SPA catch-all answers 200 with HTML for any other path, so a deeper
    # probe proves less than the root path does.
    host = inputs.self.settings.hosts.mimir.address;
  };
}
