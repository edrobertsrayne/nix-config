{lib, ...}: {
  options.flake.settings.mimir = with lib; {
    # A static LAN IP, not a Tailscale MagicDNS name: mimir's tap interface
    # is bridged directly into thor's own br0 (modules/hosts/thor/bridge.nix),
    # so thor and mimir already share an L2 segment - there is no need to
    # route this hop through Tailscale's WireGuard tunnel at all. Using the
    # bare LAN IP also sidesteps three problems a hostname would have caused:
    # nginx's proxyPass resolves a hostname once at config-load with no
    # `resolver` configured (modules/nginx.nix), Transmission's DNS-rebinding
    # Host-whitelist only exempts IP-literal Host headers (not hostnames -
    # see media/transmission.nix), and Tailscale's CGNAT range (100.64.0.0/10)
    # may not be recognised as "local" by Servarr's
    # auth.type = DisabledForLocalAddresses the way a plain LAN IP would be.
    #
    # Must match modules/hosts/mimir/mimir.nix's own br0 address - that file
    # reads this option rather than declaring the literal a second time.
    address = mkOption {
      type = types.str;
      default = "192.168.68.129";
    };
  };
}
