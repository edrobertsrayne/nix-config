{
  inputs,
  lib,
  ...
}: {
  flake.lib.mkProxiedService = {
    name,
    subdomain,
    port,
    group,
    description,
    icon,
    host ? "127.0.0.1",
    websockets ? true,
    extraConfig ? "",
    aliases ? [],
  }: let
    inherit (inputs.self.settings.server) domain;
    url = "${subdomain}.${domain}";
    aliasUrls = map (a: "${a}.${domain}") aliases;
    vhostConfig = {
      locations."/" =
        {
          proxyPass = "http://${host}:${toString port}";
          proxyWebsockets = websockets;
        }
        // lib.optionalAttrs (extraConfig != "") {inherit extraConfig;};
    };
  in {
    services.nginx.virtualHosts =
      {"${url}" = vhostConfig;}
      // lib.genAttrs aliasUrls (_: vhostConfig);

    homepage.services."${group}" = [
      {
        "${name}" = {
          href = "https://${url}";
          inherit description icon;
          siteMonitor = "http://${host}:${toString port}";
        };
      }
    ];
  };
}
