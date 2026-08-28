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

  flake.modules.nixos.bazarr-proxy = inputs.self.lib.mkProxiedService {
    name = "Bazarr";
    subdomain = "bazarr";
    port = ports.media.bazarr;
    group = "Media";
    description = "Subtitle manager";
    icon = "bazarr.png";
    host = inputs.self.settings.hosts.mimir.tailnetName;
  };
}
