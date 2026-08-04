{inputs, ...}: let
  inherit (inputs.self.settings) ports user;
  port = ports.codeServer;
in {
  flake.modules.nixos.code-server = {config, ...}: {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Code Server";
        subdomain = "code";
        inherit port;
        group = "Productivity";
        description = "VS Code in browser";
        icon = "code-server.png";
        probePath = "/healthz";
      })
    ];

    age.secrets.code-server.file = ../secrets/code-server.age;

    services.code-server = {
      enable = true;
      user = user.username;
      group = "users";
      host = "127.0.0.1";
      inherit port;
      auth = "password";
      extraArguments = ["/home/${user.username}"];
      disableTelemetry = true;
      disableUpdateCheck = true;
    };

    systemd.services.code-server.serviceConfig.EnvironmentFile =
      config.age.secrets.code-server.path;
  };
}
