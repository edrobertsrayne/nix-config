{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.thor = {pkgs, ...}: let
    alloyConfig = pkgs.writeText "config.alloy" ''
      loki.relabel "journal" {
        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label  = "unit"
        }
        rule {
          source_labels = ["__journal__hostname"]
          target_label  = "hostname"
        }
        rule {
          source_labels = ["__journal_priority_keyword"]
          target_label  = "level"
        }
        forward_to = []
      }

      loki.source.journal "read" {
        max_age       = "12h"
        labels        = { job = "systemd-journal", host = "thor" }
        relabel_rules = loki.relabel.journal.rules
        forward_to    = [loki.write.default.receiver]
      }

      loki.write "default" {
        endpoint {
          url = "http://thor:${toString ports.loki}/loki/api/v1/push"
        }
      }
    '';
  in {
    services.alloy = {
      enable = true;
      configPath = alloyConfig;
      extraFlags = ["--disable-reporting"];
    };
  };

  flake.modules.nixos.prometheus = _: {
    services.prometheus.scrapeConfigs = [
      {
        job_name = "alloy";
        static_configs = [
          {
            # alloy binds 127.0.0.1 by default (no openFirewall / 0.0.0.0 bind like the other exporters)
            targets = ["127.0.0.1:${toString ports.alloy}"];
          }
        ];
      }
    ];
  };
}
