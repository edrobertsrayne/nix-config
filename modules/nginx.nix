_: {
  flake.modules.nixos.nginx = {
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;

      # WebSocket upgrade support
      appendHttpConfig = ''
        map $http_upgrade $connection_upgrade {
          default upgrade;
          "" close;
        }
      '';

      # Status endpoint for nginx-exporter
      statusPage = true;
    };

    # No global firewall opening: nginx is reached only via
    # cloudflared -> 127.0.0.1:80 (thor.nix tunnel ingress) and, for admin,
    # over the tailnet (tailscale0 is in firewall.trustedInterfaces,
    # tailscale.nix). The LAN bridge (br0) must not reach nginx directly or
    # it bypasses Cloudflare Access.
  };
}
