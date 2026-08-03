{inputs, ...}: let
  inherit (inputs.self.settings) ports;
  service = "sonarr";
in {
  flake.modules.nixos.sonarr = {
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

    age.secrets."${service}-apikey" = {
      file = ../../secrets/${service}-apikey.age;
      owner = cfg.user;
      group = cfg.user;
    };

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
          };
        };
        environmentFiles = [config.age.secrets."${service}-apikey".path];
      };
    };

    users.users.${cfg.user}.extraGroups = ["tank"];

    systemd.services.${service}.serviceConfig.UMask = lib.mkForce "0002";
  };
}
