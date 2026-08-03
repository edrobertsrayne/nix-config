{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
in {
  flake.modules.nixos.portainer = {
    virtualisation.oci-containers = {
      backend = "docker";
      containers.portainer = {
        image = "portainer/portainer-ce:latest";
        autoStart = true;

        # Loopback-bound: Docker publishes ports via DOCKER-USER, which
        # bypasses networking.firewall, so this is the only way to keep the
        # LAN bridge out. Reached via cloudflared -> nginx (Access-gated);
        # not reachable on these raw ports from the tailnet.
        ports = [
          "127.0.0.1:${toString ports.portainerHTTPS}:9443"
          "127.0.0.1:${toString ports.portainer}:9000"
          "127.0.0.1:${toString ports.portainerEdge}:8000"
        ];

        # Raw socket, not a socket-proxy: Portainer needs POST/CONTAINERS/
        # EXEC/IMAGES/VOLUMES to function, and that set already permits a
        # privileged container with / mounted -> same root-equivalence a
        # proxy would claim to remove. Real control is Access-gating the
        # vhost plus the loopback-only ports above.
        volumes = [
          "portainer_data:/data"
          "/var/run/docker.sock:/var/run/docker.sock"
        ];

        extraOptions = [
          "--pull=always"
        ];
      };
    };

    services.nginx.virtualHosts."portainer.${server.domain}" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString ports.portainer}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header X-Forwarded-Port $server_port;
          proxy_buffering off;
        '';
      };
    };

    homepage.services."Infrastructure" = [
      {
        Portainer = {
          href = "https://portainer.${server.domain}";
          description = "Container manager";
          icon = "portainer.png";
          siteMonitor = "http://127.0.0.1:${toString ports.portainer}";
        };
      }
    ];
  };
}
