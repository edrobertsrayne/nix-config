{inputs, ...}: let
  inherit (inputs.self.settings) ports;
  service = "prowlarr";
in {
  flake.modules.nixos.prowlarr = {config, ...}: {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Prowlarr";
        subdomain = "prowlarr";
        port = ports.media.prowlarr;
        group = "Media";
        description = "Indexer manager";
        icon = "prowlarr.png";
      })
    ];

    # prowlarr runs with DynamicUser; no static owner/group to give this
    # secret, so it stays root-owned/default like ntfy-alert-topics.
    age.secrets."${service}-apikey".file = ../../secrets/${service}-apikey.age;

    services = {
      ${service} = {
        enable = true;
        dataDir = "/srv/${service}";
        # No openFirewall: reached via cloudflared -> nginx (Access-gated) or
        # the tailnet; the LAN bridge must not reach it directly.
        settings = {
          server.port = ports.media.prowlarr;
          auth = {
            method = "External";
            type = "DisabledForLocalAddresses";
          };
        };
        environmentFiles = [config.age.secrets."${service}-apikey".path];
      };
      flaresolverr.enable = true;
    };

    systemd.services.prowlarr.serviceConfig.SupplementaryGroups = ["tank"];
  };
}
