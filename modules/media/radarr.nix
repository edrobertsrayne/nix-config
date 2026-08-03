{inputs, ...}: let
  inherit (inputs.self.settings) ports;
  apikey = "45f0ce64ed8b4d34b51908c60b7a70fc";
  service = "radarr";
in {
  flake.modules.nixos.radarr = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.${service};
  in {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Radarr";
        subdomain = "radarr";
        port = ports.media.radarr;
        group = "Media";
        description = "Movie manager";
        icon = "radarr.png";
      })
    ];

    services = {
      ${service} = {
        enable = true;
        dataDir = "/srv/${service}";
        # No openFirewall: reached via cloudflared -> nginx (Access-gated) or
        # the tailnet; the LAN bridge must not reach it directly.
        settings = {
          server.port = ports.media.radarr;
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
