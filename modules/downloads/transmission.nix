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
      # This setting opens peer-port on TCP and UDP. The previous hand-rolled
      # allowedTCPPorts setting missed UDP, which dht-enabled and utp-enabled need
      # for inbound peer discovery. The RPC port itself stays closed (openRPCPort
      # defaults off). nginx on thor reaches it over the LAN bridge, through the
      # source-scoped firewall rule in hosts/mimir/mimir.nix, not through a
      # blanket port opening.
      openPeerPorts = true;
      settings = {
        # This binds to 0.0.0.0, not loopback. nginx on thor now reaches this
        # service across hosts, over br0 (#203 moved transmission to mimir).
        # mimir's own firewall (hosts/mimir/mimir.nix, scoped to thor's br0
        # address only) is what keeps this service from being LAN-reachable, not
        # the bind address. rpc-whitelist below is the second layer of protection.
        rpc-bind-address = "0.0.0.0";
        rpc-port = ports.media.transmission;
        peer-port = ports.media.transmissionPeer;

        rpc-whitelist-enabled = true;
        # This is thor's br0 address (modules/settings/hosts.nix), the source of
        # nginx's proxy_pass call. This call now crosses hosts over the LAN
        # bridge that mimir and thor share, not over the tailnet.
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

  # See docs/deploying.md, "Same-host vs. cross-host services", for why this module exists.
  flake.modules.nixos.transmission-proxy = inputs.self.lib.mkProxiedService {
    name = "Transmission";
    subdomain = "transmission";
    port = ports.media.transmission;
    group = "Media";
    description = "Torrent downloader";
    icon = "transmission.png";
    # This module sets no probePath. By design, /transmission/rpc answers 409
    # (the session-id handshake). The root URL redirects to /transmission/web/
    # with a 301, and the probe follows this redirect.
    host = inputs.self.settings.hosts.mimir.address;
  };
}
