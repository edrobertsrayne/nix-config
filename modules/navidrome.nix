{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.navidrome = {config, ...}: {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Navidrome";
        subdomain = "music";
        port = ports.media.navidrome;
        group = "Media";
        description = "Music streaming";
        icon = "navidrome.png";
        probePath = "/ping";
      })
    ];

    services.navidrome = {
      enable = true;
      settings = {
        # 0.0.0.0, not 127.0.0.1: Subsonic mobile clients need
        # <tailscale-ip>:4533 directly. No openFirewall (it would open every
        # interface); the firewall is the boundary, so only loopback (nginx) and
        # tailscale0 reach this port. Same pattern as immich.nix.
        Address = "0.0.0.0";
        Port = ports.media.navidrome;
        MusicFolder = "/mnt/ssd/music"; # auto read-only bind-mounted by module
      };
    };

    # parity with other media services (music tree is world-readable, so this
    # is belt-and-braces in case perms ever tighten)
    users.users.${config.services.navidrome.user}.extraGroups = ["tank"];

    environment.persistence."/persist".directories = ["/var/lib/navidrome"];
  };
}
