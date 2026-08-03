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
      # host stays 0.0.0.0, not 127.0.0.1, so the tailnet can reach
      # <tailscale-ip>:2283 directly - see #174. There's no split-horizon
      # DNS for photos.${domain} (blocky.nix), so the mobile app's backup
      # path can't go through the Access-gated tunnel; it hits the port by
      # tailnet IP instead. The firewall is the actual boundary here, not
      # the bind address: no openFirewall means br0 never reaches this
      # port, only loopback (nginx) and tailscale0 (trusted interface, see
      # tailscale.nix) can. This is a deliberate divergence from the
      # loopback-only binds on transmission/searxng/n8n, which are
      # admin-only UIs with no non-Access client.
      host = "0.0.0.0";
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
