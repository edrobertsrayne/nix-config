{inputs, ...}: {
  # The download stack: needs Mullvad-exit-node traffic for privacy, so it
  # runs on mimir (a microvm) rather than thor. See #203.
  flake.modules.nixos.downloads.imports = with inputs.self.modules.nixos; [
    bazarr
    lidarr
    prowlarr
    radarr
    sabnzbd
    slskd
    sonarr
    soularr
    transmission
  ];
}
