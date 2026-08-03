{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
in {
  flake.modules.nixos.sabnzbd = {config, ...}: let
    cfg = config.services.sabnzbd;
    url = "sabnzbd.${server.domain}";
  in {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "SABnzbd";
        subdomain = "sabnzbd";
        port = ports.media.sabnzbd;
        group = "Media";
        description = "Usenet downloader";
        icon = "sabnzbd.png";
        extraConfig = ''
          proxy_set_header X-Forwarded-Host $host;
        '';
      })
    ];

    services = {
      sabnzbd = {
        enable = true;
        # No openFirewall: reached via cloudflared -> nginx (Access-gated) or
        # the tailnet; the LAN bridge must not reach it directly.
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
  };
}
