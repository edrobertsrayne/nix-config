{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  url = "ntfy.${server.domain}";
  port = ports.ntfy;
in {
  flake.modules.nixos.ntfy = {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Ntfy";
        subdomain = "ntfy";
        inherit port;
        group = "Tools";
        description = "Push notifications";
        icon = "ntfy.png";
        probePath = "/v1/health";
      })
    ];

    services.ntfy-sh = {
      enable = true;
      settings = {
        base-url = "https://${url}";
        listen-http = ":${toString port}";
        behind-proxy = true;
      };
    };
  };
}
