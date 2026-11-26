# Some settings borrowed from Srvos
{
  flake.modules.nixos.networking = {lib, ...}: {
    networking = {
      useNetworkd = lib.mkDefault true;

      # Trust boundary: tailscale0 is the only trustedInterfaces
      # entry (tailscale.nix) - the LAN bridge br0 (hosts/thor/bridge.nix)
      # is untrusted, same as the WAN. Everything not listed below is
      # loopback + tailscale0 only, reached via nginx (cloudflared ->
      # Access-gated) or by <tailscale-ip>:<port> for mobile clients (no
      # split-horizon DNS exists for the public domain - see immich.nix,
      # navidrome.nix). A service that binds 0.0.0.0 with no firewall
      # opening is tailnet-reachable but not LAN-reachable; that's
      # deliberate for anything with a mobile client, since the public
      # domain can't do the app's login there.
      #
      # Ports deliberately open on br0 (the untrusted LAN), and why:
      #   22/tcp                   ssh.nix              key-only admin access
      #   53/tcp+udp               blocky.nix            thor *is* the LAN's DNS server
      #   5353/udp + mDNS          avahi.nix             service discovery is link-local
      #   137-139,445/tcp          samba.nix             guest-read media/music (Sonos etc.)
      #   8096/tcp,1900+7359/udp   jellyfin.nix          LAN players; Jellyfin auths itself
      #   8200/tcp,1900/udp        dlna.nix              DLNA is LAN-only; same tree as guest SMB
      # And on mimir's own firewall, for the download stack:
      #   51413/tcp+udp            downloads/transmission.nix inbound BitTorrent peers (WAN, via router)
      #   50300/tcp                downloads/slskd.nix   inbound Soulseek peers (WAN, via router)
      firewall = {
        enable = true;
        allowPing = true;
        logRefusedConnections = lib.mkDefault false;
      };
    };
    systemd = {
      services = {
        systemd-networkd.stopIfChanged = false;
      };
      network.wait-online.enable = false;
    };
  };
}
