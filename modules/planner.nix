{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  url = "planner.${server.domain}";
  port = ports.planner;
  image = "ghcr.io/edrobertsrayne/planner:latest";
in {
  flake.modules.nixos.planner = {
    config,
    pkgs,
    ...
  }: let
    unit = "${config.virtualisation.oci-containers.backend}-planner.service";
    autoUpdate = pkgs.writeShellScript "planner-auto-update" ''
      set -Eeuo pipefail

      docker=${pkgs.docker}/bin/docker
      curl=${pkgs.curl}/bin/curl

      # Topic in plain sight, unlike ntfy-alert-topics: ntfy's own access
      # control plus the cloudflared/tailnet boundary is the protection, not
      # the name. This posts on loopback, so it needs no token either.
      notify() {
        $curl -fsS -H "Title: $1" -H "Tags: $2" -H "Priority: $3" -d "$4" \
          "http://127.0.0.1:${toString ports.ntfy}/planner" >/dev/null || true
      }

      trap 'notify "Planner update failed" warning high "See journalctl -u planner-auto-update"' ERR

      # Compare image IDs across the pull rather than digests: the pull is a
      # cheap manifest check when nothing changed, and this stays correct
      # whether the image is a single manifest or a multi-arch index.
      before=$($docker image inspect --format '{{.Id}}' ${image} 2>/dev/null || echo none)
      $docker pull --quiet ${image} >/dev/null
      after=$($docker image inspect --format '{{.Id}}' ${image})

      if [ "$before" = "$after" ]; then
        exit 0
      fi

      ${config.systemd.package}/bin/systemctl restart ${unit}

      # Each push leaves the previous :latest untagged; without this
      # /srv/docker grows by an image a day. Dangling only — prune never
      # touches an image a container is using.
      $docker image prune -f >/dev/null

      notify "Planner updated" rocket default "Now running ''${after#sha256:}"
    '';
  in {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Planner";
        subdomain = "planner";
        inherit port;
        group = "Productivity";
        description = "Digital teacher planner";
        icon = "mdi-calendar-check";
        probe = false;
      })
    ];

    age.secrets.planner.file = ../secrets/planner.age;

    virtualisation.oci-containers.containers.planner = {
      inherit image;
      autoStart = true;
      ports = ["${toString port}:3000"];
      volumes = ["/srv/planner:/app/data"];
      environment = {
        DATABASE_URL = "/app/data/planner.db";
        ORIGIN = "https://${url}";
        BETTER_AUTH_URL = "https://${url}";
        PROTOCOL_HEADER = "x-forwarded-proto";
        HOST_HEADER = "x-forwarded-host";
      };
      environmentFiles = [config.age.secrets.planner.path];
      extraOptions = ["--pull=always"];
    };

    systemd = {
      tmpfiles.rules = [
        "d /srv/planner 0750 root root -"
      ];

      services.planner-auto-update = {
        description = "Pull ghcr.io/edrobertsrayne/planner:latest and restart planner if it changed";
        after = ["docker.service" "network-online.target"];
        wants = ["network-online.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = autoUpdate;
        };
      };

      timers.planner-auto-update = {
        description = "Check ghcr for a new planner image";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "5m";
          OnUnitActiveSec = "5m";
          AccuracySec = "30s";
        };
      };
    };
  };
}
