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
        # <tailscale-ip>:4533 directly - the hostname resolves on-tailnet
        # now too (#197) but still isn't enough for the app, see
        # docs/networking.md#split-horizon-dns-for-the-tailnet-not-the-lan.
        # No openFirewall is set (it would open every interface, not just
        # tailscale0); the firewall is the actual boundary: br0 and docker0
        # can't reach this port, only loopback (nginx) and tailscale0 can.
        # Same pattern as immich.nix. See #174.
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
