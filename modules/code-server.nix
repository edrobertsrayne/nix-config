{inputs, ...}: let
  inherit (inputs.self.settings) server ports user;
  url = "code.${server.domain}";
  port = ports.codeServer;
in {
  flake.modules.nixos.code-server = _: {
    services.code-server = {
      enable = true;
      user = user.username;
      group = "users";
      host = "127.0.0.1";
      inherit port;
      auth = "none";
      extraArguments = ["/home/${user.username}"];
      disableTelemetry = true;
      disableUpdateCheck = true;
    };

    services.nginx.virtualHosts."${url}" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString port}";
        proxyWebsockets = true;
      };
    };

    homepage.services."Productivity" = [
      {
        "Code Server" = {
          href = "https://${url}";
          description = "VS Code in browser";
          icon = "code-server.png";
          siteMonitor = "http://127.0.0.1:${toString port}";
        };
      }
    ];
  };
}
