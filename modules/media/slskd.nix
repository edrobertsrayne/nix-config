{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  service = "slskd";
  downloadDir = "/mnt/ssd/downloads/slskd";
in {
  flake.modules.nixos.media = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.${service};
  in {
    age.secrets.slskd.file = ../../secrets/slskd.age;

    users.users.${cfg.user}.extraGroups = ["tank"];

    systemd.tmpfiles.rules = [
      "d ${downloadDir}/complete 0755 ${cfg.user} tank -"
      "d ${downloadDir}/incomplete 0755 ${cfg.user} tank -"
    ];

    services.slskd = {
      enable = true;
      openFirewall = true;
      environmentFile = config.age.secrets.slskd.path;
      settings = {
        web = {
          port = ports.media.slskd;
          authentication.disabled = true;
        };
        soulseek.listen_port = ports.media.slskdListen;
        directories = {
          downloads = "${downloadDir}/complete";
          incomplete = "${downloadDir}/incomplete";
        };
        shares.directories = ["${downloadDir}/complete"];
      };
    };

    systemd.services.${service}.serviceConfig = {
      UMask = lib.mkForce "0002";
      # shares.directories == directories.downloads here (downloads-only sharing),
      # so drop the auto-derived ReadOnlyPaths that would otherwise conflict
      # with ReadWritePaths for the same directory.
      ReadOnlyPaths = lib.mkForce [];
    };

    services.nginx.virtualHosts."${service}.${server.domain}".locations."/" = {
      proxyPass = "http://127.0.0.1:${toString ports.media.slskd}";
      proxyWebsockets = true;
    };

    homepage.services."Media" = [
      {
        Slskd = {
          href = "https://${service}.${server.domain}";
          description = "Soulseek client";
          icon = "slskd.png";
          siteMonitor = "http://127.0.0.1:${toString ports.media.slskd}";
        };
      }
    ];
  };
}
