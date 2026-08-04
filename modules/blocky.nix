{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.blocky = {
    config,
    pkgs,
    lib,
    ...
  }: {
    services = {
      resolved.enable = lib.mkForce false;

      blocky = {
        enable = true;
        settings = {
          ports = {
            inherit (ports) dns;
            http = ports.blocky;
          };
          upstreams.groups.default = [
            "https://dns.mullvad.net/dns-query"
          ];
          prometheus = {
            enable = true;
            path = "/metrics";
          };
          caching = {
            minTime = "5m";
            maxTime = "30m";
            prefetching = true;
          };
          bootstrapDns = {
            upstream = "https://dns.mullvad.net/dns-query";
            ips = [
              "194.242.2.2"
              "2a07:e340::2"
            ];
          };
          queryLog = {
            type = "postgresql";
            target = "postgres://blocky@/blocky?host=/run/postgresql&sslmode=disable";
            logRetentionDays = 30;
          };
          blocking = {
            loading.strategy = "fast";
            denylists = {
              ads = [
                "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
                "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/light.txt"
                "https://raw.githubusercontent.com/lassekongo83/Frellwits-filter-lists/master/Frellwits-Swedish-Hosts-File.txt"
                "https://v.firebog.net/hosts/AdguardDNS.txt"
                (pkgs.writeText "adblock.txt" ''
                  mediavisor.doubleclick.net
                  affiliationjs.s3.amazonaws.com
                  afs.googlesyndication.com
                '')
              ];
              trackers = [
                "https://v.firebog.net/hosts/Easyprivacy.txt"
                "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.amazon.txt"
                "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.apple.txt"
                "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.huawei.txt"
                "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.winoffice.txt"
                "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.tiktok.extended.txt"
                "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.lgwebos.txt"
                "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.vivo.txt"
                "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.oppo-realme.txt"
                "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.xiaomi.txt"
                (pkgs.writeText "trackers.txt" ''
                  api.luckyorange.com
                  cdn.luckyorange.com
                  w1.luckyorange.com
                  ads.facebook.com
                  advertising.twitter.com
                  widgets.pinterest.com
                  samsung-com.112.2o7.net
                  api.bugsnag.com
                  app.bugsnag.com
                  browser.sentry-cdn.com
                  app.getsentry.com
                  adm.hotjar.com
                  identify.hotjar.com
                  insights.hotjar.com
                  surveys.hotjar.com
                  tools.mouseflow.com
                  cdn-test.mouseflow.com
                  realtime.luckyorange.com
                  claritybt.freshmarketer.com
                  fwtracks.freshmarketer.com
                  udcm.yahoo.com
                  log.fc.yahoo.com
                  adtech.yahooinc.com
                  appmetrica.yandex.ru
                  metrika.yandex.ru
                '')
              ];
            };
            allowlists = {
              ads = [
                (pkgs.writeText "whitelist.txt" ''
                  clients4.google.com
                  clients2.google.com
                  s.youtube.com
                  video-stats.youtube.com
                  www.googleapis.com
                  youtubei.googleapis.com
                  oauthaccountmanager.googleapis.com
                  android.clients.google.com
                  reminders-pa.googleapis.com
                  firestore.googleapis.com
                  gstaticadssl.l.google.com
                  googleapis.l.google.com
                  dl.google.com
                  redirector.gvt1.com
                  mtalk.google.com
                '')
              ];
            };
            clientGroupsBlock = {
              default = [
                "ads"
                "trackers"
              ];
            };
          };
        };
      };

      postgresql = {
        enable = true;
        ensureDatabases = ["blocky"];
        ensureUsers = [
          {
            name = "blocky";
            ensureDBOwnership = true;
          }
          # Grafana reads the query log for the blocky-query dashboard. It
          # connects over the unix socket, so peer auth matches this role to
          # the grafana system user; no password is involved.
          {
            name = "grafana";
          }
        ];
      };

      grafana.provision.datasources.settings = {
        # Paired with the datasource below; see modules/grafana.nix for why.
        deleteDatasources = [
          {
            name = "Blocky";
            orgId = 1;
          }
        ];

        # The url is a socket directory, not a host: Grafana's postgres
        # driver treats a leading / as a unix socket and authenticates by
        # peer, so no secret is needed.
        datasources = [
          {
            name = "Blocky";
            uid = "blocky-postgres";
            type = "postgres";
            access = "proxy";
            url = "/run/postgresql";
            user = "grafana";
            jsonData = {
              database = "blocky";
              sslmode = "disable";
              postgresVersion = 1600;
            };
          }
        ];
      };
    };

    systemd.services = {
      blocky = {
        after = ["postgresql.service"];
        requires = ["postgresql.service"];
      };

      # ensureUsers creates the role but cannot grant on a table, and
      # log_entries is created by blocky at runtime rather than by a schema
      # we control. ALTER DEFAULT PRIVILEGES covers tables blocky creates
      # later; the plain GRANT covers whatever already exists.
      blocky-grafana-grants = {
        description = "Grant Grafana read access to the blocky query log";
        after = [
          "postgresql.service"
          "blocky.service"
        ];
        requires = ["postgresql.service"];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          User = "postgres";
        };
        script = ''
          ${config.services.postgresql.package}/bin/psql -d blocky <<'SQL'
            GRANT USAGE ON SCHEMA public TO grafana;
            GRANT SELECT ON ALL TABLES IN SCHEMA public TO grafana;
            ALTER DEFAULT PRIVILEGES FOR ROLE blocky IN SCHEMA public
              GRANT SELECT ON TABLES TO grafana;
          SQL
        '';
      };
    };

    networking.firewall = {
      allowedTCPPorts = [ports.dns];
      allowedUDPPorts = [ports.dns];
    };

    monitoring.dashboards = {
      blocky = ./dashboards/blocky.json;
      blocky-query = ./dashboards/blocky-query.json;
    };

    services.prometheus.scrapeConfigs = [
      {
        job_name = "blocky";
        static_configs = [
          {
            targets = ["127.0.0.1:${toString ports.blocky}"];
          }
        ];
      }
    ];
  };
}
