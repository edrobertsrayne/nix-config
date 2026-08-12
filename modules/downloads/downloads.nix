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

  # nginx.virtualHosts entries for the download stack above, which runs on
  # mimir - not thor. Split out from the service definitions themselves so
  # this half lands on thor, the only host that runs nginx and holds the
  # cloudflared tunnel; the service half stays on mimir. See #203.
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
