{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  url = "n8n.${server.domain}";
  port = ports.n8n;
in {
  flake.modules.nixos.n8n = {config, ...}: {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "n8n";
        subdomain = "n8n";
        inherit port;
        group = "Productivity";
        description = "Workflow automation";
        icon = "n8n.png";
        probePath = "/healthz";
      })
    ];

    age.secrets.n8n.file = ../secrets/n8n.age;

    services.n8n = {
      enable = true;
      environment = {
        N8N_PORT = toString port;
        # N8N_HOST is the public-hostname hint, not the bind address (that's
        # N8N_LISTEN_ADDRESS below, which defaults to 0.0.0.0) - the old
        # value here was simply wrong, harmless only because WEBHOOK_URL and
        # N8N_EDITOR_BASE_URL are set explicitly.
        N8N_HOST = url;
        # Loopback only: reached via nginx (cloudflared -> Access-gated, or
        # the tailnet), same reasoning as searxng.nix's bind_address. Auth
        # is n8n's own user-management (owner account configured; verified
        # unauthenticated REST calls 401) plus Access on the vhost - no
        # extra nginx basic-auth layer, per repo policy.
        N8N_LISTEN_ADDRESS = "127.0.0.1";
        WEBHOOK_URL = "https://${url}/";
        N8N_EDITOR_BASE_URL = "https://${url}/";
        GENERIC_TIMEZONE = "Europe/London";
        N8N_ENCRYPTION_KEY_FILE = config.age.secrets.n8n.path;
      };
    };
  };
}
