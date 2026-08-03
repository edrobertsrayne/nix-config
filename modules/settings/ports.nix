{lib, ...}: {
  options.flake.settings.ports = with lib; {
    # Infrastructure
    ssh = mkOption {
      type = types.port;
      default = 22;
    };
    http = mkOption {
      type = types.port;
      default = 80;
    };
    https = mkOption {
      type = types.port;
      default = 443;
    };
    dns = mkOption {
      type = types.port;
      default = 53;
    };
    # Monitoring
    prometheus = mkOption {
      type = types.port;
      default = 9090;
    };
    alertmanager = mkOption {
      type = types.port;
      default = 9093;
    };
    alertmanagerNtfy = mkOption {
      type = types.port;
      default = 9094;
    };
    grafana = mkOption {
      type = types.port;
      default = 3000;
    };
    loki = mkOption {
      type = types.port;
      default = 3100;
    };
    alloy = mkOption {
      type = types.port;
      default = 12345;
    };
    # Exporters (9xxx series)
    exporters = mkOption {
      type = types.submodule {
        options = {
          node = mkOption {
            type = types.port;
            default = 9100;
          };
          zfs = mkOption {
            type = types.port;
            default = 9134;
          };
          cadvisor = mkOption {
            type = types.port;
            default = 9338;
          };
          smartctl = mkOption {
            type = types.port;
            default = 9633;
          };
          blackbox = mkOption {
            type = types.port;
            default = 9115;
          };
        };
      };
      default = {};
    };

    # Media services
    media = mkOption {
      type = types.submodule {
        options = {
          jellyfin = mkOption {
            type = types.port;
            default = 8096;
          };
          seerr = mkOption {
            type = types.port;
            default = 5055;
          };
          radarr = mkOption {
            type = types.port;
            default = 7878;
          };
          sonarr = mkOption {
            type = types.port;
            default = 8989;
          };
          lidarr = mkOption {
            type = types.port;
            default = 8686;
          };
          bazarr = mkOption {
            type = types.port;
            default = 6767;
          };
          prowlarr = mkOption {
            type = types.port;
            default = 9696;
          };
          sabnzbd = mkOption {
            type = types.port;
            default = 8080;
          };
          transmission = mkOption {
            type = types.port;
            default = 9091;
          };
          transmissionPeer = mkOption {
            type = types.port;
            default = 51413;
          };
          flaresolverr = mkOption {
            type = types.port;
            default = 8191;
          };
          slskd = mkOption {
            type = types.port;
            default = 5030;
          };
          slskdListen = mkOption {
            type = types.port;
            default = 50300;
          };
          soularr = mkOption {
            type = types.port;
            default = 8265;
          };
          navidrome = mkOption {
            type = types.port;
            default = 4533;
          };
          minidlna = mkOption {
            type = types.port;
            default = 8200;
          };
        };
      };
      default = {};
    };

    # Applications
    blocky = mkOption {
      type = types.port;
      default = 4000;
    };
    vaultwarden = mkOption {
      type = types.port;
      default = 8222;
    };
    portainer = mkOption {
      type = types.port;
      default = 9000;
    };
    portainerHTTPS = mkOption {
      type = types.port;
      default = 9443;
    };
    portainerEdge = mkOption {
      type = types.port;
      default = 8000;
    };
    karakeep = mkOption {
      type = types.port;
      default = 8081;
    };
    mealie = mkOption {
      type = types.port;
      default = 8223;
    };
    stirlingPdf = mkOption {
      type = types.port;
      default = 8082;
    };
    n8n = mkOption {
      type = types.port;
      default = 5678;
    };
    ntfy = mkOption {
      type = types.port;
      default = 2586;
    };
    immich = mkOption {
      type = types.port;
      default = 2283;
    };
    codeServer = mkOption {
      type = types.port;
      default = 8888;
    };
    searxng = mkOption {
      type = types.port;
      default = 8083;
    };
    homepage = mkOption {
      type = types.port;
      default = 8086;
    };
    paperless = mkOption {
      type = types.port;
      default = 28981;
    };
    joplin = mkOption {
      type = types.port;
      default = 22300;
    };
    bentopdf = mkOption {
      type = types.port;
      default = 8085;
    };

    # Bar Assistant
    barAssistant = mkOption {
      type = types.submodule {
        options = {
          server = mkOption {
            type = types.port;
            default = 8087;
          };
          meilisearch = mkOption {
            type = types.port;
            default = 8088;
          };
          saltRim = mkOption {
            type = types.port;
            default = 8089;
          };
        };
      };
      default = {};
    };
  };
}
