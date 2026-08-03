{inputs, ...}: let
  inherit (inputs.self.settings) ports;
  port = ports.uptimeKuma;
in {
  flake.modules.nixos.uptime-kuma = {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Uptime Kuma";
        subdomain = "uptime";
        inherit port;
        group = "Infrastructure";
        description = "Service status page";
        icon = "uptime-kuma.png";
      })
    ];

    # Kept as a status page only, not a second alerting path: blackbox-exporter
    # already probes every proxied service via monitoring.probeTargets and
    # ServiceProbeFailed routes to ntfy (modules/alert-rules.nix). This is the
    # human-facing view over the same ground, so its /metrics endpoint is
    # deliberately not scraped.
    #
    # Monitors live in uptime-kuma's SQLite state under /var/lib and are not
    # declared in-repo — the service has no declarative config surface for them.
    # Same treatment as vaultwarden and ntfy-sh; durability is covered by #169
    # (backups) and #166 (persistence). See #179.
    services.uptime-kuma = {
      enable = true;
      settings = {
        HOST = "127.0.0.1";
        PORT = toString port;
      };
    };
  };
}
