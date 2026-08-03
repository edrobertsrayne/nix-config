{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.portainer = {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Portainer";
        subdomain = "portainer";
        port = ports.portainer;
        group = "Infrastructure";
        description = "Container manager";
        icon = "portainer.png";
        extraConfig = ''
          proxy_set_header X-Forwarded-Port $server_port;
          proxy_buffering off;
        '';
      })
    ];

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
  };
}
