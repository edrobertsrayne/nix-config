{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  service = "navidrome";
in {
  flake.modules.nixos.media = {config, ...}: {
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

    services.nginx.virtualHosts."${service}.${server.domain}".locations."/" = {
      proxyPass = "http://127.0.0.1:${toString ports.media.navidrome}";
      proxyWebsockets = true;
    };

    homepage.services."Media" = [
      {
        Navidrome = {
          href = "https://${service}.${server.domain}";
          description = "Music streaming";
          icon = "navidrome.png";
          siteMonitor = "http://127.0.0.1:${toString ports.media.navidrome}";
        };
      }
    ];
  };
}
