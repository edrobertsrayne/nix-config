{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.unbound = _: {
    services.unbound = {
      enable = true;
      settings.server = {
        interface = ["127.0.0.1"];
        port = ports.unbound;
        access-control = ["127.0.0.0/8 allow"];
        do-ip6 = false;
        outgoing-interface = ["192.168.68.128"];
        hide-identity = true;
        hide-version = true;
        harden-glue = true;
        harden-dnssec-stripped = true;
        use-caps-for-id = false;
        prefetch = true;
        qname-minimisation = true;
      };
    };

    # Mark unbound's outbound packets with 0x80000 so Tailscale's own
    # policy-routing rule (5210: fwmark 0x80000/0xff0000 → main table)
    # bypasses table 52 / the Mullvad exit node, letting unbound reach
    # root servers directly via br0.
    networking.firewall.extraCommands = ''
      iptables -t mangle -C OUTPUT -m owner --uid-owner unbound \
        -j MARK --set-xmark 0x80000/0xff0000 2>/dev/null || \
      iptables -t mangle -A OUTPUT -m owner --uid-owner unbound \
        -j MARK --set-xmark 0x80000/0xff0000
    '';
    networking.firewall.extraStopCommands = ''
      iptables -t mangle -D OUTPUT -m owner --uid-owner unbound \
        -j MARK --set-xmark 0x80000/0xff0000 2>/dev/null || true
    '';
  };
}
