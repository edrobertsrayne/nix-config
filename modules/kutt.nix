{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  port = ports.kutt;
in {
  flake.modules.nixos.kutt = {config, ...}: {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Kutt";
        subdomain = "go";
        inherit port;
        group = "Tools";
        description = "URL shortener";
        icon = "kutt.png";
        websockets = false;
        probePath = "/api/v2/health";
      })
    ];

    # Holds `JWT_SECRET`. go.<domain> is bypassed in Cloudflare Access so
    # short links work for anyone; Kutt's own login is the only gate on
    # creating and managing links.
    age.secrets.kutt.file = ../secrets/kutt.age;

    # SQLite database lives here. Under /srv, so it is already covered by the
    # thor-state restic snapshot.
    systemd.tmpfiles.rules = ["d /srv/kutt 0755 root root -"];

    # Not in nixpkgs, so it runs as a container. Floating tag + --pull=always
    # follows the repo convention for rolling images.
    virtualisation.oci-containers.containers.kutt = {
      image = "kutt/kutt:latest";
      autoStart = true;
      ports = ["127.0.0.1:${toString port}:3000"];
      volumes = ["/srv/kutt:/var/lib/kutt"];
      environment = {
        DEFAULT_DOMAIN = "go.${server.domain}";
        SITE_NAME = "Greensroad Links";
        DB_CLIENT = "better-sqlite3";
        DB_FILENAME = "/var/lib/kutt/data.sqlite";
        DISALLOW_REGISTRATION = "true";
        DISALLOW_ANONYMOUS_LINKS = "true";
        TRUST_PROXY = "true";
      };
      environmentFiles = [config.age.secrets.kutt.path];
      extraOptions = ["--pull=always"];
    };
  };
}
