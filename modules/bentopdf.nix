{inputs, ...}: let
  inherit (inputs.self.settings) ports;
  port = ports.bentopdf;
in {
  flake.modules.nixos.bentopdf = {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "BentoPDF";
        subdomain = "pdf";
        inherit port;
        group = "Tools";
        description = "PDF toolkit";
        icon = "pdf.png";
        extraConfig = "client_max_body_size 100m;";
      })
    ];

    virtualisation.oci-containers.containers.bentopdf = {
      image = "ghcr.io/alam00000/bentopdf-simple:latest";
      autoStart = true;
      ports = ["${toString port}:8080"];
      # :latest + --pull=always is deliberate, not an oversight: personal
      # server, nixpkgs is already tracked on unstable, rolling container
      # images are an accepted trade for staying current without manual
      # version bumps. See #181.
      extraOptions = ["--pull=always"];
    };
  };
}
