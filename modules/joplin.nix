{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  url = "joplin.${server.domain}";
  port = ports.joplin;
in {
  flake.modules.nixos.joplin = {
    systemd.tmpfiles.rules = [
      "d /srv/joplin 0750 1001 1001 -"
    ];

    virtualisation.oci-containers.containers.joplin-server = {
      image = "joplin/server:latest";
      autoStart = true;
      ports = ["${toString port}:22300"];
      volumes = ["/srv/joplin:/home/joplin/data"];
      environment = {
        APP_BASE_URL = "https://${url}";
        APP_PORT = "22300";
        DB_CLIENT = "sqlite3";
        SQLITE_DATABASE = "/home/joplin/data/db.sqlite";
      };
      extraOptions = ["--pull=always"];
    };

    services.nginx.virtualHosts."${url}".locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
    };

    homepage.services."Productivity" = [
      {
        Joplin = {
          href = "https://${url}";
          description = "Note sync server";
          icon = "joplin.png";
          siteMonitor = "http://127.0.0.1:${toString port}";
        };
      }
    ];
  };
}
