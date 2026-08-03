{inputs, ...}: let
  inherit (inputs.self.settings) ports;
  apikey = "f6a4315040e94c7c9eb2aefe5bfc4445";
  service = "lidarr";
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
        name = "Lidarr";
        subdomain = "lidarr";
        port = ports.media.lidarr;
        group = "Media";
        description = "Music manager";
        icon = "lidarr.png";
      })
    ];

    services = {
      ${service} = {
        enable = true;
        dataDir = "/srv/${service}";
        # No openFirewall: reached via cloudflared -> nginx (Access-gated) or
        # the tailnet; the LAN bridge must not reach it directly.
        settings = {
          server.port = ports.media.lidarr;
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
