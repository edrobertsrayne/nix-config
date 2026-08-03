{inputs, ...}: {
  flake.modules.nixos.media.imports = with inputs.self.modules.nixos; [
    bazarr
    dlna
    jellyfin
    lidarr
    navidrome
    prowlarr
    radarr
    sabnzbd
    seerr
    slskd
    sonarr
    soularr
    transmission
  ];
}
