{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  apikey = "f6a4315040e94c7c9eb2aefe5bfc4445";
  service = "lidarr";
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
          server.port = ports.media.lidarr;
          auth = {
            method = "External";
            type = "DisabledForLocalAddresses";
            inherit apikey;
          };
        };
      };
    };

    services.nginx.virtualHosts."${service}.${server.domain}" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${builtins.toString cfg.settings.server.port}";
        proxyWebsockets = true;
      };
    };

    users.users.${cfg.user}.extraGroups = ["tank"];

    homepage.services."Media" = [
      {
        Lidarr = {
          href = "https://${service}.${server.domain}";
          description = "Music manager";
          icon = "lidarr.png";
          siteMonitor = "http://127.0.0.1:${toString ports.media.lidarr}";
        };
      }
    ];
  };
}
