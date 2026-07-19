{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  url = "cocktails.${server.domain}";
  p = ports.barAssistant;
  net = "bar-assistant";
in {
  flake.modules.nixos.bar-assistant = {
    config,
    pkgs,
    ...
  }: {
    age.secrets.bar-assistant.file = ../secrets/bar-assistant.age;

    systemd = {
      # server storage bind-mount; owned by www-data (33:33) per upstream docs
      tmpfiles.rules = [
        "d /srv/bar-assistant 0755 root root -"
        "d /srv/bar-assistant/data 0755 33 33 -"
      ];

      services = {
        # user-defined network so bar-assistant-server can resolve meilisearch by name
        init-bar-assistant-network = {
          after = ["docker.service"];
          requires = ["docker.service"];
          wantedBy = ["multi-user.target"];
          serviceConfig.Type = "oneshot";
          script = ''
            ${pkgs.docker}/bin/docker network inspect ${net} >/dev/null 2>&1 \
              || ${pkgs.docker}/bin/docker network create ${net}
          '';
        };

        "docker-meilisearch" = {
          after = ["init-bar-assistant-network.service"];
          requires = ["init-bar-assistant-network.service"];
        };
        "docker-bar-assistant-server" = {
          after = ["init-bar-assistant-network.service"];
          requires = ["init-bar-assistant-network.service"];
        };
      };
    };

    virtualisation.oci-containers.containers = {
      meilisearch = {
        image = "getmeili/meilisearch:v1.15";
        autoStart = true;
        ports = ["127.0.0.1:${toString p.meilisearch}:7700"];
        volumes = ["bar_assistant_meili:/meili_data"];
        environment = {
          MEILI_NO_ANALYTICS = "true";
          MEILI_ENV = "production";
        };
        environmentFiles = [config.age.secrets.bar-assistant.path];
        extraOptions = ["--pull=always" "--network=${net}"];
      };

      bar-assistant-server = {
        image = "barassistant/server:v5";
        autoStart = true;
        dependsOn = ["meilisearch"];
        ports = ["127.0.0.1:${toString p.server}:8080"];
        volumes = ["/srv/bar-assistant/data:/var/www/cocktails/storage/bar-assistant"];
        environment = {
          APP_URL = "https://${url}/bar";
          MEILISEARCH_HOST = "http://meilisearch:7700";
          CACHE_DRIVER = "file";
          SESSION_DRIVER = "file";
          ALLOW_REGISTRATION = "true";
        };
        environmentFiles = [config.age.secrets.bar-assistant.path];
        extraOptions = ["--pull=always" "--network=${net}"];
      };

      salt-rim = {
        image = "barassistant/salt-rim:v4";
        autoStart = true;
        dependsOn = ["bar-assistant-server"];
        ports = ["127.0.0.1:${toString p.saltRim}:8080"];
        environment = {
          API_URL = "https://${url}/bar";
          MEILISEARCH_URL = "https://${url}/search";
        };
        extraOptions = ["--pull=always"];
      };
    };

    # single vhost, subpath routing. Trailing slashes strip /bar and /search
    # prefixes before forwarding, as required by Bar Assistant.
    services.nginx.virtualHosts."${url}" = {
      extraConfig = "client_max_body_size 100m;";
      locations = {
        "/bar/".proxyPass = "http://127.0.0.1:${toString p.server}/";
        "/search/".proxyPass = "http://127.0.0.1:${toString p.meilisearch}/";
        "/" = {
          proxyPass = "http://127.0.0.1:${toString p.saltRim}/";
          proxyWebsockets = true;
        };
      };
    };

    homepage.services."Food & Drink" = [
      {
        "Bar Assistant" = {
          href = "https://${url}";
          description = "Home bar & cocktail manager";
          icon = "bar-assistant.png";
          siteMonitor = "http://127.0.0.1:${toString p.saltRim}";
        };
      }
    ];
  };
}
