{inputs, ...}: {
  flake.modules.nixos.njord = {pkgs, ...}: let
    # dokploy-traefik is a plain container (Dokploy's install script, not a
    # Swarm service) on the swarm-scoped `dokploy-network` overlay. After a
    # hard reboot dockerd can start it before Swarm's overlay networking is
    # ready; the attach fails, it exits 255, and restart policy `always` never
    # retries — admin/slicer sat on 502 for ~14h (#223). Swarm has no loop for
    # plain containers, so this is that loop.
    #
    # Starting is not always enough. After a VM restart a stopped container can
    # fail every start with `Address already in use` on the overlay, and
    # Dokploy's scheduled cleanup then prunes it and its image. So a container
    # that won't start or is gone gets recreated with install.sh's run args. To
    # take traefik down on purpose, stop this unit's timer first.
    watchdog = pkgs.writeShellScript "dokploy-traefik-watchdog" ''
      set -euo pipefail

      docker=${pkgs.docker}/bin/docker
      name=dokploy-traefik
      # Only used when the container is gone; a container that won't start
      # keeps its own image. Keep in step with Dokploy's install.sh.
      default_image=traefik:v3.6.25

      recreate() {
        $docker run -d \
          --name "$name" --restart always \
          --network dokploy-network \
          -v /etc/dokploy/traefik/traefik.yml:/etc/traefik/traefik.yml \
          -v /etc/dokploy/traefik/dynamic:/etc/dokploy/traefik/dynamic \
          -v /var/run/docker.sock:/var/run/docker.sock:ro \
          -p 80:80/tcp -p 443:443/tcp -p 443:443/udp \
          "$1"
      }

      # Docker 29 prints a blank line on stdout for a missing container, so
      # test the exit status rather than appending to the output.
      if ! running=$($docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null); then
        running=missing
      fi
      if [ "$running" = false ]; then
        echo "$name is stopped, starting it"
        if ! $docker start "$name"; then
          image=$($docker inspect -f '{{.Config.Image}}' "$name")
          echo "$name would not start, recreating it from $image"
          $docker rm -f "$name"
          recreate "$image"
        fi
      elif [ "$running" = missing ]; then
        echo "$name does not exist, creating it from $default_image"
        recreate "$default_image"
      fi
    '';
  in {
    # Publishes docker_container_running, so ContainerStopped also fires if
    # the watchdog itself can't bring traefik back.
    imports = [inputs.self.modules.nixos.docker-health];

    systemd = {
      services.dokploy-traefik-watchdog = {
        description = "Start or recreate dokploy-traefik if it is not running";
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
