{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.blocky = {
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
            ips = ["194.242.2.2" "2a07:e340::2"];
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
              default = ["ads" "trackers"];
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
        ];
      };
    };

    systemd.services.blocky = {
      after = ["postgresql.service"];
      requires = ["postgresql.service"];
    };

    networking.firewall = {
      allowedTCPPorts = [ports.dns];
      allowedUDPPorts = [ports.dns];
    };
  };

  flake.modules.nixos.prometheus = _: {
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
