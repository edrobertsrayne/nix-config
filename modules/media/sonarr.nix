{inputs, ...}: let
  inherit (inputs.self.settings) ports;
  apikey = "e6619670253d4b17baaa8a640a3aafed";
  service = "sonarr";
in {
  flake.modules.nixos.media = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.${service};
  in {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Sonarr";
        subdomain = "sonarr";
        port = ports.media.sonarr;
        group = "Media";
        description = "TV series manager";
        icon = "sonarr.png";
      })
    ];

    services = {
      ${service} = {
        enable = true;
        dataDir = "/srv/${service}";
        # No openFirewall: reached via cloudflared -> nginx (Access-gated) or
        # the tailnet; the LAN bridge must not reach it directly.
        settings = {
          server.port = ports.media.sonarr;
          auth = {
            method = "External";
            type = "DisabledForLocalAddresses";
            inherit apikey;
          };
        };
      };
    };

    users.users.${cfg.user}.extraGroups = ["tank"];

    systemd.services.${service}.serviceConfig.UMask = lib.mkForce "0002";
  };
}
