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
      "d ${cfg.settings.incomplete-dir} 0755 ${cfg.user} tank -"
      "d ${cfg.settings.download-dir} 0755 ${cfg.user} tank -"
    ];

    services.transmission = {
      enable = true;
      home = lib.mkDefault "/srv/transmission";
      package = pkgs.transmission_4;
      # Opens peer-port on TCP *and* UDP; the previous hand-rolled
      # allowedTCPPorts missed UDP, which dht-enabled/utp-enabled need for
      # inbound peer discovery. RPC port itself stays off (openRPCPort
      # defaults off) - it's reached over the LAN bridge from thor's nginx,
      # via the source-scoped firewall rule in hosts/mimir/mimir.nix, not a
      # blanket port opening.
      openPeerPorts = true;
      settings = {
        # 0.0.0.0, not loopback: nginx reaches this cross-host from thor over
        # br0 now (#203 - transmission moved to mimir), so mimir's own
        # firewall (hosts/mimir/mimir.nix, scoped to thor's br0 address only)
        # is what keeps this from being LAN-reachable, not the bind address.
        # rpc-whitelist below is the second layer.
        rpc-bind-address = "0.0.0.0";
        rpc-port = ports.media.transmission;
        peer-port = ports.media.transmissionPeer;

        rpc-whitelist-enabled = true;
        # thor's br0 address (modules/settings/hosts.nix) - nginx's
        # proxy_pass source, now that it's a cross-host call over the LAN
        # bridge mimir and thor share, not the tailnet.
        rpc-whitelist = "127.0.0.1,::1,${inputs.self.settings.hosts.thor.address}";
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
  };

  # Runs on mimir (#203); this vhost is what actually makes it reachable -
  # it must be imported by thor, the only host with nginx/cloudflared.
  flake.modules.nixos.transmission-proxy = inputs.self.lib.mkProxiedService {
    name = "Transmission";
    subdomain = "transmission";
    port = ports.media.transmission;
    group = "Media";
    description = "Torrent downloader";
    icon = "transmission.png";
    # No probePath: /transmission/rpc answers 409 by design (the session-id
    # handshake). The root URL 301s to /transmission/web/ and the probe
    # follows it.
    host = inputs.self.settings.hosts.mimir.address;
  };
}
