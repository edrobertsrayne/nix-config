{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  apikey = "c20dce066e08419daaa4c2cbbe4ddcbe";
  service = "prowlarr";
in {
  flake.modules.nixos.media = {config, ...}: let
    cfg = config.services.${service};
  in {
    services = {
      ${service} = {
        enable = true;
        dataDir = "/srv/${service}";
        openFirewall = true;
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

    systemd.tmpfiles.rules = [
      "d ${config.services.prowlarr.dataDir} 0755 prowlarr prowlarr - -"
    ];

    services.nginx.virtualHosts."${service}.${server.domain}" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${builtins.toString cfg.settings.server.port}";
        proxyWebsockets = true;
      };
    };

    homepage.services."Media" = [
      {
        Prowlarr = {
          href = "https://${service}.${server.domain}";
          description = "Indexer manager";
          icon = "prowlarr.png";
          siteMonitor = "http://127.0.0.1:${toString ports.media.prowlarr}";
        };
      }
    ];
  };
}
