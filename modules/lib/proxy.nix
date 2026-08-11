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
    probe ? true,
    probePath ? "",
  }: let
    inherit (inputs.self.settings.server) domain;
    url = "${subdomain}.${domain}";
    aliasUrls = map (a: "${a}.${domain}") aliases;
    vhostConfig = {
      addSSL = true;
      useACMEHost = domain;
      locations."/" =
        {
          proxyPass = "http://${host}:${toString port}";
          proxyWebsockets = websockets;
        }
        // lib.optionalAttrs (extraConfig != "") {inherit extraConfig;};
    };
    backendUrl = "http://${host}:${toString port}";
  in {
    services.nginx.virtualHosts =
      {"${url}" = vhostConfig;}
      // lib.genAttrs aliasUrls (_: vhostConfig);

    homepage.services."${group}" = [
      {
        "${name}" = {
          href = "https://${url}";
          inherit description icon;
          siteMonitor = backendUrl;
        };
      }
    ];

    # Keyed by name, not URL: the key becomes the probe's instance label, so
    # Grafana legends and ntfy alerts say "Prowlarr" rather than
    # "http://127.0.0.1:9696". probePath aims the probe at a health endpoint
    # where the service has one — see modules/hosts/thor/blackbox-exporter.nix.
    monitoring.probeTargets = lib.optionalAttrs probe {
      "${name}" = "${backendUrl}${probePath}";
    };
  };
}
