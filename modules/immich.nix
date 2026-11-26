{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.immich = {config, ...}: let
    cfg = config.services.immich;
    mediaDir = "/mnt/ssd/immich";
  in {
    imports = [
      inputs.self.modules.nixos.intel-vaapi
      inputs.self.modules.nixos.postgresql
      (inputs.self.lib.mkProxiedService {
        name = "Immich";
        subdomain = "photos";
        port = ports.immich;
        group = "Library";
        description = "Photo library";
        icon = "immich.png";
        host = "127.0.0.1";
        probePath = "/api/server/ping";
      })
    ];

    services.immich = {
      enable = true;
      port = ports.immich;
      # 0.0.0.0, not 127.0.0.1: the mobile app needs <tailscale-ip>:2283
      # directly. The firewall is the boundary, not the bind address: no
      # openFirewall, so only loopback (nginx) and tailscale0 (trusted) reach
      # this port. Unlike the loopback-only admin UIs
      # (transmission/searxng/n8n), this has a non-Access client.
      host = "0.0.0.0";
      mediaLocation = mediaDir;
    };

    users.users.${cfg.user}.extraGroups = ["video" "render"];

    systemd.tmpfiles.rules = [
      "d ${mediaDir} 0755 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.systemd-tmpfiles-setup.after = ["mnt-ssd.mount"];

    environment.persistence."/persist".directories = ["/var/lib/redis-immich"];
  };
}
