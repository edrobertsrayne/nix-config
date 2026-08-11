{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.jellyfin = {
    pkgs,
    config,
    ...
  }: {
    imports = [
      inputs.self.modules.nixos.intel-vaapi
      (inputs.self.lib.mkProxiedService {
        name = "Jellyfin";
        subdomain = "jellyfin";
        port = ports.media.jellyfin;
        group = "Library";
        description = "Media server";
        icon = "jellyfin.png";
        probePath = "/health";
      })
    ];

    services = {
      jellyfin = {
        enable = true;
        dataDir = "/srv/jellyfin";
        # No openFirewall: it expands (nixpkgs jellyfin.nix) to a *global*
        # opening on every interface, not just br0 - docker0 and any virbr*
        # too. Scope the LAN opening explicitly below instead.
      };
    };

    # Deliberate LAN opening (see #174): local players talk to
    # 192.168.68.128:8096 directly. Blocky's split-horizon mapping (#197,
    # docs/blocky.md) only reaches clients that use blocky for DNS, and LAN
    # devices don't - they take DNS from the router, not thor - so
    # jellyfin.${server.domain} still resolves publicly for a TV/Kodi app on
    # the LAN, and the Access-gated tunnel path isn't usable from it. Unlike the Servarr apps, this
    # isn't an auth bypass - Jellyfin requires its own login regardless of
    # source address. 8920 (HTTPS) stays closed: no TLS cert is configured
    # for it.
    networking.firewall.interfaces.br0 = {
      allowedTCPPorts = [ports.media.jellyfin];
      allowedUDPPorts = [1900 7359]; # SSDP + Jellyfin client auto-discovery
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
  };
}
