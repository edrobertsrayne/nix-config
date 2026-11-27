{inputs, ...}: {
  # Runs on mimir (a microvm), not thor: the stack needs Mullvad exit-node
  # traffic.
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

  # thor-side nginx vhosts for the services that run on mimir.
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
