{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
in {
  flake.modules.nixos.karakeep = {
    config,
    lib,
    pkgs,
    ...
  }: let
    url = "keep.${server.domain}";
    port = ports.karakeep;
  in {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Karakeep";
        subdomain = "keep";
        inherit port;
        group = "Productivity";
        description = "Bookmark manager";
        icon = "karakeep.png";
        probePath = "/api/health";
      })
    ];

    nixpkgs.config.permittedInsecurePackages = ["pnpm-9.15.9"];
    age.secrets.karakeep.file = ../secrets/karakeep.age;
    services = {
      karakeep = {
        enable = true;
        extraEnvironment = {
          PORT = "${toString port}";
          NEXTAUTH_URL = "https://${url}";
        };
        environmentFile = config.age.secrets.karakeep.path;
      };
    };

    systemd.services.karakeep-web.serviceConfig = {
      Restart = "on-failure";
      RestartSec = "5s";
    };

    fonts = {
      fontconfig.enable = lib.mkForce true;
      packages = [pkgs.noto-fonts];
    };

    environment.persistence."/persist".directories = [
      "/var/lib/karakeep"
      "/var/lib/private/karakeep-browser"
      "/var/lib/private/meilisearch"
    ];
  };
}
