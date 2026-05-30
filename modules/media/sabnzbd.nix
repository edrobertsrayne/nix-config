{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
in {
  flake.modules.nixos.media = {config, ...}: let
    cfg = config.services.sabnzbd;
    url = "sabnzbd.${server.domain}";
  in {
    services = {
      sabnzbd = {
        enable = true;
        openFirewall = true;
        configFile = null;
        settings.misc = {
          host_whitelist = "localhost, 127.0.0.1, ${url}";
          local_ranges = "127.0.0.1, ::1";
          inet_exposure = 4;
          download_dir = "/mnt/ssd/downloads/usenet/incomplete";
          complete_dir = "/mnt/ssd/downloads/usenet/complete";
          permissions = "777";
        };
      };
    };

    users.users.${cfg.user}.extraGroups = ["tank"];

    systemd.tmpfiles.rules = [
      "d /mnt/ssd/downloads/usenet/complete 0755 ${cfg.user} tank -"
      "d /mnt/ssd/downloads/usenet/incomplete 0755 ${cfg.user} tank -"
    ];

    services.nginx.virtualHosts."${url}" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString ports.media.sabnzbd}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header X-Forwarded-Host $host;
        '';
      };
    };

    homepage.services."Media" = [
      {
        SABnzbd = {
          href = "https://${url}";
          description = "Usenet downloader";
          icon = "sabnzbd.png";
          siteMonitor = "http://127.0.0.1:${toString ports.media.sabnzbd}";
        };
      }
    ];
  };
}
