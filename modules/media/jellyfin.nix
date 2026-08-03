{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.media = {
    pkgs,
    config,
    ...
  }: {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Jellyfin";
        subdomain = "jellyfin";
        port = ports.media.jellyfin;
        group = "Library";
        description = "Media server";
        icon = "jellyfin.png";
      })
    ];

    services = {
      jellyfin = {
        enable = true;
        dataDir = "/srv/jellyfin";
        openFirewall = true;
      };
    };

    users.users.${config.services.jellyfin.user}.extraGroups = ["tank"];

    environment.systemPackages = [
      pkgs.jellyfin
      pkgs.jellyfin-web
      pkgs.jellyfin-ffmpeg
    ];

    nixpkgs.config.packageOverrides = pkgs: {
      vaapiIntel = pkgs.vaapiIntel.override {enableHybridCodec = true;};
    };

    # Enable intro skipper plugin
    nixpkgs.overlays = with pkgs; [
      (
        _final: prev: {
          jellyfin-web = prev.jellyfin-web.overrideAttrs (_finalAttrs: _previousAttrs: {
            installPhase = ''
              runHook preInstall

              # this is the important line
              sed -i "s#</head>#<script src=\"configurationpage?name=skip-intro-button.js\"></script></head>#" dist/index.html

              mkdir -p $out/share
              cp -a dist $out/share/jellyfin-web

              runHook postInstall
            '';
          });
        }
      )
    ];

    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-vaapi-driver # previously vaapiIntel
        libva-vdpau-driver
        libvdpau-va-gl
        intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
        vpl-gpu-rt # QSV on 11th gen or newer
        intel-media-driver # QSV up to 11th gen
      ];
    };
  };
}
