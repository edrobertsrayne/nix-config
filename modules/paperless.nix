{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  url = "paperless.${server.domain}";
  port = ports.paperless;
in {
  flake.modules.nixos.paperless = {config, ...}: {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Paperless";
        subdomain = "paperless";
        inherit port;
        group = "Productivity";
        description = "Document management";
        icon = "paperless-ngx.png";
        # No probePath: paperless-ngx has no unauthenticated health endpoint.
        # The root URL 302s to /accounts/login/ and the probe follows it.
      })
    ];

    age.secrets.paperless = {
      file = ../secrets/paperless.age;
      owner = "paperless";
      group = "paperless";
    };

    services.paperless = {
      enable = true;
      inherit port;
      dataDir = "/srv/paperless";
      consumptionDir = "/srv/paperless/consume";
      consumptionDirIsPublic = true;
      settings = {
        PAPERLESS_URL = "https://${url}";
        PAPERLESS_OCR_LANGUAGE = "eng";
        PAPERLESS_TIME_ZONE = "Europe/London";
      };
      environmentFile = config.age.secrets.paperless.path;
    };
  };
}
