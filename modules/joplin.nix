{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  url = "joplin.${server.domain}";
  port = ports.joplin;
in {
  flake.modules.nixos.joplin = {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Joplin";
        subdomain = "joplin";
        inherit port;
        group = "Productivity";
        description = "Note sync server";
        icon = "joplin.png";
        # Joplin Server 404s on a direct backend request unless Host matches
        # APP_BASE_URL, so a blackbox probe against the bare backend URL can't work.
        probe = false;
      })
    ];

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
  };
}
