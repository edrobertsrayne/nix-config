{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.immich = {config, ...}: let
    cfg = config.services.immich;
    mediaDir = "/mnt/ssd/immich";
  in {
    imports = [
      inputs.self.modules.nixos.intel-vaapi
      (inputs.self.lib.mkProxiedService {
        name = "Immich";
        subdomain = "photos";
        port = ports.immich;
        group = "Library";
        description = "Photo library";
        icon = "immich.png";
        host = "127.0.0.1";
      })
    ];

    services.immich = {
      enable = true;
      port = ports.immich;
      host = "0.0.0.0";
      # No openFirewall: reached via cloudflared -> nginx (Access-gated) or
      # the tailnet; the LAN bridge must not reach it directly.
      mediaLocation = mediaDir;
    };

    # User permissions
    users.users.${cfg.user}.extraGroups = ["video" "render"];

    # Directory setup
    systemd.tmpfiles.rules = [
      "d ${mediaDir} 0755 ${cfg.user} ${cfg.group} -"
    ];

    # Ensure mount exists before tmpfiles
    systemd.services.systemd-tmpfiles-setup.after = ["mnt-ssd.mount"];
  };
}
