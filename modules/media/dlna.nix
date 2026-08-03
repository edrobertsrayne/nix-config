{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.dlna = {
    services.minidlna = {
      enable = true;
      # Deliberate LAN opening, not an oversight - see #174: DLNA/SSDP only
      # function on the local segment, so closing this disables the
      # service outright. No new exposure results - /mnt/ssd/music is
      # already guest-readable to the whole LAN over Samba
      # (hosts/thor/samba.nix), and minidlna serves the same tree
      # unauthenticated either way.
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
