{inputs, ...}: let
  inherit (inputs.self.settings) ports;
  inherit (inputs.self.settings.server) domain;
  port = ports.media.janitarr;
  mimir = inputs.self.settings.hosts.mimir.address;
in {
  # Runs on thor (not in the `downloads` group, which is mimir's) and talks to
  # mimir's sonarr/radarr over the LAN; mimir's firewall already accepts thor
  # on those ports. See docs/deploying.md, "Same-host vs. cross-host services".
  flake.modules.nixos.janitarr = {
    config,
    pkgs,
    ...
  }: let
    janitarr = pkgs.buildNpmPackage {
      pname = "janitarr";
      version = "0.0.1";
      src = inputs.janitarr;
      # node:sqlite needs Node 24, and the repo sets engine-strict.
      nodejs = pkgs.nodejs_24;
      npmDepsHash = "sha256-U+YBgCgcJZqEulTZngBuN3I7QWBXU11NFdDvvYQ75ic=";
      env.PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
      # Vite bundles everything, so the runtime needs no node_modules.
      dontNpmInstall = true;
      installPhase = ''
        runHook preInstall
        mkdir -p $out/lib/janitarr
        cp -r build package.json $out/lib/janitarr/
        runHook postInstall
      '';
    };

    # The agenix files hold SONARR__AUTH__APIKEY=… (servarr env format);
    # janitarr wants SONARR_API_KEY. Extract at start so keys never hit disk.
    start = pkgs.writeShellScript "janitarr-start" ''
      key() { ${pkgs.gnused}/bin/sed -n "s/^$2=//p" "$CREDENTIALS_DIRECTORY/$1"; }
      export SONARR_API_KEY=$(key sonarr SONARR__AUTH__APIKEY)
      export RADARR_API_KEY=$(key radarr RADARR__AUTH__APIKEY)
      exec ${pkgs.nodejs_24}/bin/node ${janitarr}/lib/janitarr/build
    '';
  in {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Janitarr";
        subdomain = "janitarr";
        inherit port;
        group = "Media";
        description = "Sonarr/Radarr queue cleaner";
        icon = "mdi-broom";
        probePath = "/api/health";
      })
    ];

    # Distinct names: mkArr uses <service>-apikey on mimir.
    age.secrets = {
      janitarr-sonarr-apikey.file = ../../secrets/sonarr-apikey.age;
      janitarr-radarr-apikey.file = ../../secrets/radarr-apikey.age;
    };

    users = {
      users.janitarr = {
        isSystemUser = true;
        group = "janitarr";
      };
      groups.janitarr = {};
    };

    systemd = {
      tmpfiles.rules = ["d /srv/janitarr 0700 janitarr janitarr -"];

      services.janitarr = {
        wantedBy = ["multi-user.target"];
        after = ["network-online.target"];
        wants = ["network-online.target"];
        unitConfig.RequiresMountsFor = ["/srv/janitarr"];
        environment = {
          NODE_ENV = "production";
          HOST = "127.0.0.1";
          PORT = toString port;
          ORIGIN = "https://janitarr.${domain}";
          JANITARR_DATA_DIR = "/srv/janitarr";
          SONARR_URL = "http://${mimir}:${toString ports.media.sonarr}";
          RADARR_URL = "http://${mimir}:${toString ports.media.radarr}";
        };
        serviceConfig = {
          ExecStart = start;
          User = "janitarr";
          Group = "janitarr";
          LoadCredential = [
            "sonarr:${config.age.secrets.janitarr-sonarr-apikey.path}"
            "radarr:${config.age.secrets.janitarr-radarr-apikey.path}"
          ];
          Restart = "on-failure";
          RestartSec = "30s";
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = ["/srv/janitarr"];
        };
      };
    };
  };
}
