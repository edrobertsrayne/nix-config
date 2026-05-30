{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  url = "pdf.${server.domain}";
  port = ports.bentopdf;
in {
  flake.modules.nixos.bentopdf = {
    virtualisation.oci-containers.containers.bentopdf = {
      image = "ghcr.io/alam00000/bentopdf-simple:latest";
      autoStart = true;
      ports = ["${toString port}:8080"];
      extraOptions = ["--pull=always"];
    };

    services.nginx.virtualHosts."${url}".locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
      extraConfig = "client_max_body_size 100m;";
    };

    homepage.services."Tools" = [
      {
        BentoPDF = {
          href = "https://${url}";
          description = "PDF toolkit";
          icon = "pdf.png";
          siteMonitor = "http://127.0.0.1:${toString port}";
        };
      }
    ];
  };
}
