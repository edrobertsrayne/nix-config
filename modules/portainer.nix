{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
in {
  flake.modules.nixos.portainer = {
    virtualisation.oci-containers = {
      backend = "docker";
      containers.portainer = {
        image = "portainer/portainer-ce:latest";
        autoStart = true;

        ports = [
          "${toString ports.portainerHTTPS}:9443"
          "${toString ports.portainer}:9000"
          "${toString ports.portainerEdge}:8000"
        ];

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
