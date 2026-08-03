{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.navidrome = {config, ...}: {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Navidrome";
        subdomain = "navidrome";
        port = ports.media.navidrome;
        group = "Media";
        description = "Music streaming";
        icon = "navidrome.png";
      })
    ];

    services.navidrome = {
      enable = true;
      settings = {
        # 0.0.0.0, not 127.0.0.1: Subsonic mobile clients need
        # <tailscale-ip>:4533 directly, since there's no split-horizon DNS
        # for navidrome.${domain} (blocky.nix) to route them through the
        # Access-gated tunnel instead. No openFirewall is set (and none
        # should be - it opens the port on every interface, not just
        # tailscale0), so the firewall is the actual boundary: br0 and
        # docker0 can't reach this port, only loopback (nginx) and
        # tailscale0 (trusted interface, tailscale.nix) can. Navidrome
        # requires its own login regardless of source address, so tailnet
        # exposure is of an authenticated service. Same pattern as
        # immich.nix. See #174.
        Address = "0.0.0.0";
        Port = ports.media.navidrome;
        MusicFolder = "/mnt/ssd/music"; # auto read-only bind-mounted by module
      };
    };

    # parity with other media services (music tree is world-readable, so this
    # is belt-and-braces in case perms ever tighten)
    users.users.${config.services.navidrome.user}.extraGroups = ["tank"];
  };
}
