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

    # Deliberate LAN opening: local players talk to 192.168.68.128:8096
    # directly, since LAN devices don't use blocky for DNS. Not an auth bypass:
    # Jellyfin requires its own login regardless of source. 8920 (HTTPS) stays
    # closed: no TLS cert is configured.
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

    nixpkgs.overlays = [
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
