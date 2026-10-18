{inputs, ...}: {
  flake.modules.nixos.njord = {pkgs, ...}: let
    # dokploy-traefik is a plain container (Dokploy's install script, not a
    # Swarm service) on the swarm-scoped `dokploy-network` overlay. After a
    # hard reboot dockerd can start it before Swarm's overlay networking is
    # ready; the attach fails, it exits 255, and restart policy `always` never
    # retries — admin/slicer sat on 502 for ~14h (#223). Swarm has no loop for
    # plain containers, so this is that loop. It only starts a container that
    # exists and is stopped, so a deliberate `docker rm` stays removed.
    watchdog = pkgs.writeShellScript "dokploy-traefik-watchdog" ''
      set -euo pipefail

      docker=${pkgs.docker}/bin/docker
      name=dokploy-traefik

      # Docker 29 prints a blank line on stdout for a missing container, so
      # test the exit status rather than appending to the output.
      if ! running=$($docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null); then
        running=missing
      fi
      if [ "$running" = false ]; then
        echo "$name is stopped, starting it"
        $docker start "$name"
      elif [ "$running" = missing ]; then
        # Recreating it needs Dokploy's own run args; the njord blackbox
        # probes alert on this instead.
        echo "$name does not exist, recreate it with docker run (see modules/hosts/njord/README.md)"
      fi
    '';
  in {
    # Publishes docker_container_running, so ContainerStopped also fires if
    # the watchdog itself can't bring traefik back.
    imports = [inputs.self.modules.nixos.docker-health];

    systemd = {
      services.dokploy-traefik-watchdog = {
        description = "Start dokploy-traefik if it is stopped";
        after = ["docker.service"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = watchdog;
        };
      };

      timers.dokploy-traefik-watchdog = {
        description = "Check dokploy-traefik is running";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "1m";
          OnUnitActiveSec = "1m";
          AccuracySec = "5s";
        };
      };
    };
  };
}
