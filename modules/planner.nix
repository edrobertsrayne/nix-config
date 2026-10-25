{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  url = "planner.${server.domain}";
  port = ports.planner;
  image = "ghcr.io/edrobertsrayne/planner:latest";
in {
  flake.modules.nixos.planner = {config, ...}: {
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
    };
  };
}
