{inputs, ...}: let
  inherit (inputs.self.settings) ports;
  apikey = "c20dce066e08419daaa4c2cbbe4ddcbe";
  service = "prowlarr";
in {
  flake.modules.nixos.media = {
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
            inherit apikey;
          };
        };
      };
      flaresolverr.enable = true;
    };

    systemd.services.prowlarr.serviceConfig.SupplementaryGroups = ["tank"];
  };
}
