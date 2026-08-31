{inputs, ...}: let
  inherit (inputs.self.settings) ports server;
in {
  flake.modules.nixos.transmission = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.transmission;
  in {
    users.users.${cfg.user}.extraGroups = ["tank"];

    systemd.tmpfiles.rules = [
      # 2775: setgid so transmission's completed-download dirs inherit group
      # tank, not transmission's primary group - required for sonarr/radarr
      # (tank members) to delete the source file after copying it out.
      # /mnt/ssd/downloads and /mnt/storage are separate virtiofs mounts, so
      # imports cannot hardlink and must copy+delete.
      "d ${cfg.settings.incomplete-dir} 2775 ${cfg.user} tank -"
      "d ${cfg.settings.download-dir} 2775 ${cfg.user} tank -"
      # cfg.home lives outside the default /var/lib/transmission, so
      # StateDirectory= doesn't create it — the unit's self BindPaths= onto
      # this path (to poke a hole in ProtectSystem=strict) requires it to
      # already exist, or the service fails at NAMESPACE setup.
      "d ${cfg.home}/.config/transmission-daemon 0750 ${cfg.user} ${cfg.user} -"
    ];

    # The nixpkgs module defaults this to 0066, which leaves completed-file
    # dirs group-inaccessible and blocks the arrs' delete step even with the
    # right group. The *arrs already get 0002 from flake.lib.mkArr
    # (modules/lib/servarr.nix).
    systemd.services.transmission.serviceConfig.UMask = lib.mkForce "0002";

    services.transmission = {
      enable = true;
      home = lib.mkDefault "/srv/transmission";
      package = pkgs.transmission_4;
      openPeerPorts = true;
      settings = {
        rpc-bind-address = "0.0.0.0";
        rpc-port = ports.media.transmission;
        peer-port = ports.media.transmissionPeer;

        rpc-whitelist-enabled = true;
        # Proxied from thor, over tailscale0 (mkProxiedService's host is
        # mimir's MagicDNS name) - thor's tailnet address, not its LAN one,
        # is what transmission sees the request arrive from.
        rpc-whitelist = "127.0.0.1,::1,${inputs.self.settings.hosts.thor.address},${inputs.self.settings.hosts.thor.tailnetAddress}";
        rpc-host-whitelist-enabled = true;
        rpc-host-whitelist = "transmission.${server.domain}";

        download-dir = "/mnt/ssd/downloads/transmission/complete";
        incomplete-dir = "/mnt/ssd/downloads/transmission/incomplete";

        ratio-limit-enabled = true;
        ratio-limit = 2.0;
        seed-queue-enabled = true;
        seed-queue-size = 5;

        download-queue-enabled = true;
        download-queue-size = 10;
        queue-stalled-enabled = true;
        queue-stalled-minutes = 30;

        cache-size-mb = 16;
        prefetch-enabled = true;

        dht-enabled = true;
        lpd-enabled = false;
        pex-enabled = true;
        utp-enabled = true;

        alt-speed-enabled = false;

        blocklist-enabled = false;
      };
    };
  };

  # See docs/deploying.md, "Same-host vs. cross-host services", for why this module exists.
  flake.modules.nixos.transmission-proxy = inputs.self.lib.mkProxiedService {
    name = "Transmission";
    subdomain = "transmission";
    port = ports.media.transmission;
    group = "Media";
    description = "Torrent downloader";
    icon = "transmission.png";
    host = inputs.self.settings.hosts.mimir.tailnetName;
  };
}
