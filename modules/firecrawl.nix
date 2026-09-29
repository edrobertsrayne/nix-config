{inputs, ...}: let
  inherit (inputs.self.settings) ports;
  port = ports.firecrawl;
  net = "firecrawl";
in {
  flake.modules.nixos.firecrawl = {
    lib,
    pkgs,
    ...
  }: {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Firecrawl";
        subdomain = "firecrawl";
        inherit port;
        group = "Tools";
        description = "Self-hosted web scraping API";
        icon = "firecrawl.png";
        websockets = false;
        # API is unauthenticated (USE_DB_AUTHENTICATION=false): reachable only
        # via nginx on the tailnet. Do NOT publish this vhost through the
        # cloudflared tunnel without Access in front of it.
        probePath = "/";
      })
    ];

    # user-defined network so containers resolve each other by name
    systemd.services = {
      init-firecrawl-network = {
        after = ["docker.service"];
        requires = ["docker.service"];
        wantedBy = ["multi-user.target"];
        serviceConfig.Type = "oneshot";
        script = ''
          ${pkgs.docker}/bin/docker network inspect ${net} >/dev/null 2>&1 \
            || ${pkgs.docker}/bin/docker network create ${net}
        '';
      };
      docker-firecrawl-redis = {
        after = ["init-firecrawl-network.service"];
        requires = ["init-firecrawl-network.service"];
      };
      docker-firecrawl-rabbitmq = {
        after = ["init-firecrawl-network.service"];
        requires = ["init-firecrawl-network.service"];
      };
      docker-firecrawl-postgres = {
        after = ["init-firecrawl-network.service"];
        requires = ["init-firecrawl-network.service"];
      };
      docker-firecrawl-playwright = {
        after = ["init-firecrawl-network.service"];
        requires = ["init-firecrawl-network.service"];
      };
      docker-firecrawl-api = {
        after = ["init-firecrawl-network.service"];
        requires = ["init-firecrawl-network.service"];
        # depends_on in upstream compose waits for rabbitmq/postgres health;
        # oci-containers dependsOn only orders start, so wait for the API to
        # bind instead and let Restart=on-failure retry the race.
        serviceConfig.ExecStartPost = pkgs.writeShellScript "firecrawl-ready" ''
          for _ in $(seq 1 90); do
            ${lib.getExe pkgs.curl} -fsS -o /dev/null http://127.0.0.1:${toString port}/ && exit 0
            sleep 2
          done
          echo "firecrawl API never bound ${toString port}" >&2
          exit 1
        '';
      };
    };

    # Rolling tags + --pull=always follow the repo convention (see
    # bar-assistant.nix, #181). Pin firecrawl-api/playwright/nuq-postgres to a
    # release tag if a pull ever breaks things. Only the API is published, on
    # loopback; every dependency stays on the private docker network.
    virtualisation.oci-containers.containers = {
      firecrawl-redis = {
        image = "redis:alpine";
        autoStart = true;
        cmd = ["redis-server" "--bind" "0.0.0.0"];
        extraOptions = ["--network=${net}" "--network-alias=redis" "--memory=256m"];
      };

      firecrawl-rabbitmq = {
        image = "rabbitmq:3";
        autoStart = true;
        extraOptions = ["--network=${net}" "--network-alias=rabbitmq" "--memory=512m"];
      };

      firecrawl-postgres = {
        image = "ghcr.io/firecrawl/nuq-postgres:latest";
        autoStart = true;
        # Not published; reachable only from the private network. Default
        # creds are acceptable for that scope; move to an agenix
        # environmentFile if this ever leaves the network.
        environment = {
          POSTGRES_USER = "postgres";
          POSTGRES_PASSWORD = "postgres";
          POSTGRES_DB = "postgres";
        };
        volumes = ["firecrawl_pg:/var/lib/postgresql/data"];
        extraOptions = ["--pull=always" "--network=${net}" "--network-alias=nuq-postgres" "--memory=512m"];
      };

      firecrawl-playwright = {
        image = "ghcr.io/firecrawl/playwright-service:latest";
        autoStart = true;
        environment = {
          PORT = "3000";
          MAX_CONCURRENT_PAGES = "3";
        };
        extraOptions = [
          "--pull=always"
          "--network=${net}"
          "--network-alias=playwright-service"
          "--memory=3g"
          "--cpus=2"
          "--cap-drop=ALL"
          "--security-opt=no-new-privileges:true"
          "--tmpfs=/tmp/.cache:noexec,nosuid,size=1g"
        ];
      };

      firecrawl-api = {
        image = "ghcr.io/firecrawl/firecrawl:latest";
        autoStart = true;
        dependsOn = ["firecrawl-redis" "firecrawl-rabbitmq" "firecrawl-postgres" "firecrawl-playwright"];
        cmd = ["node" "dist/src/harness.js" "--start-docker"];
        ports = ["127.0.0.1:${toString port}:3002"];
        environment = {
          HOST = "0.0.0.0";
          PORT = "3002";
          EXTRACT_WORKER_PORT = "3004";
          WORKER_PORT = "3005";
          ENV = "local";
          REDIS_URL = "redis://redis:6379";
          REDIS_RATE_LIMIT_URL = "redis://redis:6379";
          NUQ_RABBITMQ_URL = "amqp://rabbitmq:5672";
          PLAYWRIGHT_MICROSERVICE_URL = "http://playwright-service:3000/scrape";
          POSTGRES_USER = "postgres";
          POSTGRES_PASSWORD = "postgres";
          POSTGRES_DB = "postgres";
          POSTGRES_HOST = "nuq-postgres";
          POSTGRES_PORT = "5432";
          USE_DB_AUTHENTICATION = "false";
          # Thor is memory-tight; upstream defaults (8/10/5/5) assume far more.
          NUM_WORKERS_PER_QUEUE = "2";
          CRAWL_CONCURRENT_REQUESTS = "3";
          MAX_CONCURRENT_JOBS = "2";
          BROWSER_POOL_SIZE = "2";
          # Reuse the existing SearXNG for firecrawl's own /search endpoint.
          SEARXNG_ENDPOINT = "http://host.docker.internal:${toString ports.searxng}";
        };
        extraOptions = [
          "--pull=always"
          "--network=${net}"
          "--memory=4g"
          "--cpus=4"
          "--ulimit=nofile=65535:65535"
          "--add-host=host.docker.internal:host-gateway"
        ];
      };
    };
  };
}
