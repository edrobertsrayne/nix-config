{inputs, ...}: let
  inherit (inputs.self.settings) ports;
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
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Slskd";
        subdomain = "slskd";
        port = ports.media.slskd;
        group = "Media";
        description = "Soulseek client";
        icon = "slskd.png";
      })
    ];

    age.secrets.slskd.file = ../../secrets/slskd.age;

    users.users.${cfg.user}.extraGroups = ["tank"];

    systemd.tmpfiles.rules = [
      # 2775: setgid so slskd's own per-album subdirs inherit group tank
      # (not slskd's primary group) - required for lidarr/soularr (tank
      # members) to delete imported files after copying them out.
      "d ${downloadDir}/complete 2775 ${cfg.user} tank -"
      "d ${downloadDir}/incomplete 2775 ${cfg.user} tank -"
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
  };
}
