{inputs, ...}: {
  # The download stack needs Mullvad exit-node traffic for privacy, so it
  # runs on mimir (a microvm), not on thor. See #203.
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

  # See docs/deploying.md, "Same-host vs. cross-host services", for why this split exists.
  flake.modules.nixos.downloads-proxy.imports = with inputs.self.modules.nixos; [
    bazarr-proxy
    lidarr-proxy
    prowlarr-proxy
    radarr-proxy
    sabnzbd-proxy
    slskd-proxy
    sonarr-proxy
    soularr-proxy
    transmission-proxy
  ];
}
