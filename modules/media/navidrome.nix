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
        Address = "127.0.0.1"; # localhost only; nginx fronts it
        Port = ports.media.navidrome;
        MusicFolder = "/mnt/ssd/music"; # auto read-only bind-mounted by module
      };
    };

    # parity with other media services (music tree is world-readable, so this
    # is belt-and-braces in case perms ever tighten)
    users.users.${config.services.navidrome.user}.extraGroups = ["tank"];
  };
}
