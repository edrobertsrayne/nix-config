{inputs, ...}: {
  flake.modules.nixos.nginx = {
    imports = [inputs.self.modules.nixos.acme];

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;

      # Catch-all for hostnames no vhost claims. Without an explicit default
      # server nginx hands those to the first vhost it loaded, so
      # anything.<domain> (the tunnel forwards the whole wildcard) was
      # answered by Bazarr. Plain HTTP gets a 404, which cloudflared passes
      # through as-is; HTTPS has its handshake rejected, since no certificate
      # could match the name anyway.
      virtualHosts."_" = {
        default = true;
        rejectSSL = true;
        locations."/".return = "404";
      };

      # WebSocket upgrade support
      appendHttpConfig = ''
        map $http_upgrade $connection_upgrade {
          default upgrade;
          "" close;
        }
      '';
    };

    # No global firewall opening: nginx is reached only via
    # cloudflared -> 127.0.0.1:80 (thor.nix tunnel ingress) and, for admin,
    # over the tailnet (tailscale0 is in firewall.trustedInterfaces,
    # tailscale.nix). The LAN bridge (br0) must not reach nginx directly or
    # it bypasses Cloudflare Access.

    # proxyPass targets on mimir are MagicDNS names and no resolver directive
    # is configured, so nginx resolves them once at startup and exits if that
    # fails. tailscaled must own /etc/resolv.conf before nginx reads its
    # config.
    systemd.services.nginx = {
      after = ["tailscaled.service"];
      wants = ["tailscaled.service"];
    };
  };
}
