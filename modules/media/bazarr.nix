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
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Bazarr";
        subdomain = "bazarr";
        port = ports.media.bazarr;
        group = "Media";
        description = "Subtitle manager";
        icon = "bazarr.png";
        # No probePath: /api/system/status needs X-API-KEY, which can't go in
        # the blackbox config (a world-readable store path), and the SPA
        # catch-all answers 200 with HTML for any other path, so a deeper
        # probe would prove less than the root one does.
        host = inputs.self.settings.mimir.tailscaleHost;
      })
    ];

    users.users.${cfg.user}.extraGroups = ["tank"];
    systemd.services.bazarr.serviceConfig.UMask = lib.mkForce "0002";
    services.bazarr = {
      enable = true;
      listenPort = ports.media.bazarr;
      dataDir = "/srv/bazarr";
    };
  };
}
