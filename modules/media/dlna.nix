{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.dlna = {
    services.minidlna = {
      enable = true;
      openFirewall = true; # HTTP + SSDP
      settings = {
        media_dir = ["A,/mnt/ssd/music"]; # A = audio only
        friendly_name = "thor";
        inotify = "yes";
        port = ports.media.minidlna;
      };
    };

    # music tree is world-readable; tank added for parity w/ navidrome
    users.users.minidlna.extraGroups = ["tank"];
  };
}
