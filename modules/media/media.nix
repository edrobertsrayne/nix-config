{inputs, ...}: {
  # Services that stay on thor: no privacy requirement, and they want
  # LAN-local/mobile access (see docs/networking.md). The Mullvad-exit-node
  # group lives in downloads.nix instead — see #203.
  flake.modules.nixos.media.imports = with inputs.self.modules.nixos; [
    dlna
    jellyfin
    navidrome
    seerr
  ];
}
