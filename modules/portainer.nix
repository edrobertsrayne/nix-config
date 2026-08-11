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
        probePath = "/api/system/status";
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
        # LAN bridge out. Reached via nginx (cloudflared -> Access-gated, or
        # the tailnet — split-horizon DNS + tailnet HTTPS means a tailnet
        # client hits the vhost directly, no Access login, same as
        # transmission/n8n/sabnzbd); not reachable on these raw published
        # ports from anywhere but loopback.
        ports = [
          "127.0.0.1:${toString ports.portainerHTTPS}:9443"
          "127.0.0.1:${toString ports.portainer}:9000"
          "127.0.0.1:${toString ports.portainerEdge}:8000"
        ];

        # Raw socket, not a socket-proxy: Portainer needs POST/CONTAINERS/
        # EXEC/IMAGES/VOLUMES to function, and that set already permits a
        # privileged container with / mounted -> same root-equivalence a
        # proxy would claim to remove. Real control is the loopback-only
        # ports above plus, on the vhost, Portainer's own login — accepted
        # because the tailnet is already thor's trusted admin boundary
        # (SSH, Prometheus) and a tailnet peer skips Access on this vhost
        # the same way it does on every other one.
        volumes = [
          "portainer_data:/data"
          "/var/run/docker.sock:/var/run/docker.sock"
        ];

        # :latest + --pull=always is deliberate, not an oversight: personal
        # server, nixpkgs is already tracked on unstable, rolling container
        # images are an accepted trade for staying current without manual
        # version bumps. See #181.
        extraOptions = [
          "--pull=always"
        ];
      };
    };
  };
}
