{inputs, ...}: let
  inherit (inputs.self.settings) server ports user;
  url = "code.${server.domain}";
  port = ports.codeServer;
in {
  flake.modules.nixos.code-server = {pkgs, ...}: {
    systemd.services.code-server = {
      description = "code-server VS Code in the browser";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        User = user.username;
        WorkingDirectory = "/home/${user.username}";
        ExecStart = "${pkgs.code-server}/bin/code-server --auth=none --bind-addr=127.0.0.1:${toString port} /home/${user.username}";
        Restart = "on-failure";
        RestartSec = 5;
      };
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
