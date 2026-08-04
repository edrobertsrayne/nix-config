{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  url = "vault.${server.domain}";
  port = ports.vaultwarden;
in {
  flake.modules.nixos.vaultwarden = {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Vaultwarden";
        subdomain = "vault";
        inherit port;
        group = "Tools";
        description = "Password manager";
        icon = "vaultwarden.png";
        probePath = "/alive";
      })
    ];

    services.vaultwarden = {
      enable = true;
      config = {
        ROCKET_PORT = port;
        DOMAIN = "https://${url}";
        SIGNUPS_ALLOWED = false;
        LOG_LEVEL = "warn";
        EXTENDED_LOGGING = true;
      };
    };
  };
}
