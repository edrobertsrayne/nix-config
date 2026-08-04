{inputs, ...}: let
  inherit (inputs.self.settings) ports;
  # node-exporter reads every *.prom in here; nothing else writes to it.
  textfileDir = "/var/lib/prometheus-node-exporter-textfile";
in {
  flake.modules.nixos.thor = {pkgs, ...}: let
    # Docker's own HEALTHCHECK verdict is the earliest signal that a container
    # is running but useless — Bar Assistant's API sat "unhealthy" for 16h
    # while its unit stayed active (#192). cAdvisor doesn't expose it and
    # node-exporter has no Docker collector, so publish it as a textfile.
    dockerHealth = pkgs.writeShellScript "docker-health-textfile" ''
      set -euo pipefail

      docker=${pkgs.docker}/bin/docker
      out=${textfileDir}/docker-health.prom
      tmp=$out.tmp

      {
        echo "# HELP docker_container_running 1 if the container is running."
        echo "# TYPE docker_container_running gauge"
        echo "# HELP docker_container_health_status Docker HEALTHCHECK state, 1 on the container's current state."
        echo "# TYPE docker_container_health_status gauge"

        # An unreachable daemon fails the unit rather than publishing zeroes:
        # SystemdUnitFailed catches that, and the frozen mtime trips
        # ContainerHealthCollectorStale.
        ids=$($docker ps -aq)
        if [ -n "$ids" ]; then
          $docker inspect \
            --format '{{.Name}} {{.State.Running}} {{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
            $ids \
          | while read -r name running health; do
            name=''${name#/}

            if [ "$running" = true ]; then r=1; else r=0; fi
            printf 'docker_container_running{name="%s"} %s\n' "$name" "$r"

            # Containers whose image declares no healthcheck report "none" and
            # get no health series at all.
            if [ "$health" != none ]; then
              # Every state is emitted, not just the current one: a series that
              # simply disappears only resolves once it goes stale ~5m later,
              # whereas one that flips to 0 resolves on the next scrape.
              for state in healthy unhealthy starting; do
                if [ "$state" = "$health" ]; then v=1; else v=0; fi
                printf 'docker_container_health_status{name="%s",status="%s"} %s\n' \
                  "$name" "$state" "$v"
              done
            fi
          done
        fi
      } > "$tmp"

      # node-exporter will happily read a half-written file.
      mv "$tmp" "$out"
    '';
  in {
    services = {
      cadvisor = {
        enable = true;
        port = ports.exporters.cadvisor;
      };

      prometheus = {
        exporters.node = {
          enabledCollectors = ["textfile"];
          extraFlags = ["--collector.textfile.directory=${textfileDir}"];
        };

        scrapeConfigs = [
          {
            job_name = "cadvisor";
            static_configs = [
              {
                targets = ["127.0.0.1:${toString ports.exporters.cadvisor}"];
              }
            ];
          }
        ];
      };
    };

    systemd = {
      # World-readable: node-exporter runs as its own user and only reads.
      tmpfiles.rules = ["d ${textfileDir} 0755 root root -"];

      services.docker-health-textfile = {
        description = "Publish Docker container health as node-exporter textfile metrics";
        after = ["docker.service"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = dockerHealth;
        };
      };

      timers.docker-health-textfile = {
        description = "Refresh the Docker container health metrics";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "1m";
          OnUnitActiveSec = "30s";
          AccuracySec = "5s";
        };
      };
    };

    monitoring.dashboards.cadvisor = ../../dashboards/cadvisor.json;
  };
}
