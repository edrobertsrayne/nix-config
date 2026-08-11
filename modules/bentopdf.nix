{inputs, ...}: let
  inherit (inputs.self.settings) ports;
  inherit (inputs.self.settings.server) domain;
  port = ports.bentopdf;
in {
  flake.modules.nixos.bentopdf = {
    services.bentopdf = {
      enable = true;
      domain = "pdf.${domain}";
      nginx = {
        enable = true;
        virtualHost = {
          addSSL = true;
          useACMEHost = domain;
          # Upstream serves the static build straight out of the store, so
          # there is no backend to probe. The extra loopback listener gives
          # blackbox and the homepage tile something to hit; :80 and :443
          # both have to be restated because nginx only computes its default
          # listeners when `listen` is empty — addSSL alone does not add a
          # :443 socket once `listen` is set explicitly.
          listen = [
            {
              addr = "0.0.0.0";
              port = 80;
            }
            {
              addr = "[::0]";
              port = 80;
            }
            {
              addr = "0.0.0.0";
              port = 443;
              ssl = true;
            }
            {
              addr = "[::0]";
              port = 443;
              ssl = true;
            }
            {
              addr = "127.0.0.1";
              inherit port;
            }
          ];
        };
      };
    };

    # Set directly rather than via mkProxiedService: that helper always
    # proxyPasses, and this vhost serves files from the store instead.
    homepage.services.Tools = [
      {
        BentoPDF = {
          href = "https://pdf.${domain}";
          description = "PDF toolkit";
          icon = "pdf.png";
          siteMonitor = "http://127.0.0.1:${toString port}";
        };
      }
    ];

    monitoring.probeTargets.BentoPDF = "http://127.0.0.1:${toString port}";
  };
}
