{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  # Ships the systemd journal to Loki on thor. One aspect for every host:
  # the only thing that differs is the `host` label, which follows the
  # hostname.
  flake.modules.nixos.alloy = {
    config,
    lib,
    pkgs,
    ...
  }: let
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
        labels        = { job = "systemd-journal", host = "${config.networking.hostName}" }
        relabel_rules = loki.relabel.journal.rules
        forward_to    = [loki.process.reclassify.receiver]
      }

      // Docker's journald driver tags all container stderr as priority 3, so
      // INFO lines from tools that log there (meilisearch, soularr) show up
      // as errors. Anchored to each tool's level position so an ERROR line
      // that merely mentions INFO in its body keeps its level.
      loki.process "reclassify" {
        stage.match {
          selector = "{level=\"error\"} |~ `^(\\S+Z\\s+INFO\\s|\\[INFO\\|)`"
          stage.static_labels {
            values = { level = "info" }
          }
        }
        forward_to = [loki.write.default.receiver]
      }

      loki.write "default" {
        endpoint {
          url = "http://thor:${toString ports.loki}/loki/api/v1/push"
        }
      }
    '';
  in {
    services = {
      alloy = {
        enable = true;
        configPath = alloyConfig;
        extraFlags = ["--disable-reporting"];
      };

      # alloy binds 127.0.0.1 by default, so only a Prometheus on the same
      # host can scrape it. Gated so the guests carry no dead scrape job.
      prometheus.scrapeConfigs = lib.mkIf config.services.prometheus.enable [
        {
          job_name = "alloy";
          static_configs = [
            {
              targets = ["127.0.0.1:${toString ports.alloy}"];
            }
          ];
        }
      ];
    };

    environment.persistence."/persist".directories = ["/var/lib/private/alloy"];
  };
}
