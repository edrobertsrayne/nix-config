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
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Transmission";
        subdomain = "transmission";
        port = ports.media.transmission;
        group = "Media";
        description = "Torrent downloader";
        icon = "transmission.png";
      })
    ];

    users.users.${cfg.user}.extraGroups = ["tank"];

    systemd.tmpfiles.rules = [
      "d ${cfg.settings.incomplete-dir} 0755 ${cfg.user} tank -"
      "d ${cfg.settings.download-dir} 0755 ${cfg.user} tank -"
    ];

    services.transmission = {
      enable = true;
      home = lib.mkDefault "/srv/transmission";
      package = pkgs.transmission_4;
      settings = {
        # Loopback only: reached via nginx (cloudflared -> Access-gated, or
        # over the tailnet). The firewall already keeps 9091 off br0;
        # binding narrowly means a firewall regression can't silently
        # re-expose the RPC socket.
        rpc-bind-address = "127.0.0.1";
        rpc-port = ports.media.transmission;
        peer-port = ports.media.transmissionPeer;

        rpc-whitelist-enabled = true;
        rpc-whitelist = "127.0.0.1,::1";
        # DNS-rebinding protection. Transmission always permits IP-literal
        # Host headers, so homepage's siteMonitor (http://127.0.0.1:9091)
        # still works.
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

    # RPC port stays off the LAN: reached via cloudflared -> nginx
    # (Access-gated) or the tailnet. Peer port must stay open for inbound
    # BitTorrent peers.
    networking.firewall.allowedTCPPorts = [cfg.settings.peer-port];
  };
}
