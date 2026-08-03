{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  url = "home.${server.domain}";
in {
  flake.modules.nixos.homepage = {
    config,
    lib,
    ...
  }: {
    age.secrets.homepage.file = ../secrets/homepage.age;

    services.homepage-dashboard = {
      enable = true;
      listenPort = ports.homepage;
      openFirewall = false;
      environmentFiles = [config.age.secrets.homepage.path];
      allowedHosts = url;

      settings = {
        title = "Greensroad";
        theme = "dark";
        headerStyle = "boxed";
        hideVersion = true;
      };

      services =
        lib.mapAttrsToList
        (group: items: {"${group}" = items;})
        config.homepage.services;

      widgets = [
        {
          resources = {
            cpu = true;
            memory = true;
            disk = "/";
          };
        }
        {search.provider = "duckduckgo";}
      ];
    };

    services.nginx.virtualHosts."${url}".locations."/" = {
      proxyPass = "http://127.0.0.1:${toString ports.homepage}";
      proxyWebsockets = true;
    };
  };
}
