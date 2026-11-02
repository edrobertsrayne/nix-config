{inputs, ...}: let
  inherit (inputs.self.settings) ports;
  service = "slskd";
  downloadDir = "/mnt/ssd/downloads/slskd";
in {
  flake.modules.nixos.slskd = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.${service};
  in {
    age.secrets.slskd.file = ../../secrets/slskd.age;

    users.users.${cfg.user}.extraGroups = ["tank"];

    systemd.tmpfiles.rules = [
      # 2775: setgid so slskd's own per-album subdirs inherit group tank
      # (not slskd's primary group) - required for lidarr/soularr (tank
      # members) to delete imported files after copying them out.
      "d ${downloadDir}/complete 2775 ${cfg.user} tank -"
      "d ${downloadDir}/incomplete 2775 ${cfg.user} tank -"
    ];

    services.slskd = {
      enable = true;
      # Opens ONLY the soulseek P2P listen port (50300), not the web UI -
      # see the nixpkgs option description. Required for inbound peer
      # connections; without it slskd reports as firewalled. Web port 5030
      # is reachable only from loopback, the tailnet, and docker0 (opened
      # separately in soularr.nix for the bridge).
      openFirewall = true;
      environmentFile = config.age.secrets.slskd.path;
      settings = {
        web = {
          port = ports.media.slskd;
          # Access is the auth layer (see modules/nginx.nix): the web port
          # is not LAN-exposed and the public vhost is Access-gated.
          # soularr also relies on this being off (soularr.nix:
          # api_key = disabled).
          authentication.disabled = true;
        };
        soulseek.listen_port = ports.media.slskdListen;
        directories = {
          downloads = "${downloadDir}/complete";
          incomplete = "${downloadDir}/incomplete";
        };
        shares.directories = ["${downloadDir}/complete"];
      };
    };

    systemd.services.${service} = {
      # .NET 10.0.14 moved named mutexes out of /tmp/.dotnet: it uses
      # $XDG_RUNTIME_DIR/.dotnet, or $HOME/.dotnet when that is unset. A system
      # unit has no XDG_RUNTIME_DIR and the slskd user's home is /var/empty, so
      # slskd cannot take its singleton mutex and exits at startup (#245).
      environment.XDG_RUNTIME_DIR = "/run/${service}";

      serviceConfig = {
        RuntimeDirectory = service;
        RuntimeDirectoryMode = "0700";
        # slskd exits with status 0 when it cannot start, and on-failure does
        # not retry that. With always, a repeat of #245 keeps retrying and trips
        # SystemdUnitRestartLooping (modules/alert-rules.nix) as well as
        # ProbeFailed. The delay keeps it clear of the start rate limit, which
        # would stop the retries.
        Restart = lib.mkForce "always";
        RestartSec = "30s";
        UMask = lib.mkForce "0002";
        # shares.directories == directories.downloads here (downloads-only sharing),
        # so drop the auto-derived ReadOnlyPaths that would otherwise conflict
        # with ReadWritePaths for the same directory.
        ReadOnlyPaths = lib.mkForce [];
      };
    };

    environment.persistence."/persist".directories = ["/var/lib/slskd"];
  };

  # See docs/deploying.md, "Same-host vs. cross-host services", for why this module exists.
  flake.modules.nixos.slskd-proxy = inputs.self.lib.mkProxiedService {
    name = "Slskd";
    subdomain = "slskd";
    port = ports.media.slskd;
    group = "Media";
    description = "Soulseek client";
    icon = "slskd.png";
    probePath = "/health";
    host = inputs.self.settings.hosts.mimir.tailnetName;
  };
}
