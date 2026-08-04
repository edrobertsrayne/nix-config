{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.stirling-pdf = {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Stirling PDF";
        subdomain = "stirling-pdf";
        port = ports.stirlingPdf;
        group = "Tools";
        description = "PDF toolkit";
        icon = "stirling-pdf.png";
        # Returns {"version": ..., "status": "UP"} without authentication.
        # Unverified — stirling-pdf is commented out of thor.nix, so check it
        # on activation; upstream has shipped versions where this endpoint
        # reports itself disabled.
        probePath = "/api/v1/info/status";
      })
    ];

    services.stirling-pdf = {
      enable = true;
      # nixpkgs dropped services.stirling-pdf.port; the module now passes
      # everything through to the app as environment variables.
      environment.SERVER_PORT = ports.stirlingPdf;
    };
  };
}
