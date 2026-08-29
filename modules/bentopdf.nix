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
          # there's no backend to probe - the loopback listener is for
          # blackbox/homepage instead. :80 and :443 both have to be restated:
          # nginx only computes default listeners when `listen` is empty, so
          # addSSL alone won't add a :443 socket here.
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
          icon = "bentopdf.png";
          siteMonitor = "http://127.0.0.1:${toString port}";
        };
      }
    ];

    monitoring.probeTargets.BentoPDF = "http://127.0.0.1:${toString port}";
  };
}
