{inputs, ...}: {
  flake.lib.mkArr = {
    service,
    name,
    port,
    description,
    icon,
    secret,
    dynamicUser ? false,
    umask ? true,
    # null leaves the upstream module's default in place. Prowlarr needs that:
    # a custom dataDir there means a bind mount plus a root-owned tmpfiles rule
    # that fights its DynamicUser (#194).
    dataDir ? "/srv/${service}",
    # /ping is the only *arr endpoint reachable without an API key, and it
    # checks database access rather than just answering — a Servarr app whose
    # database is unopenable keeps serving its UI on / but returns 500 here.
    probePath ? "/ping",
    # 127.0.0.1 (mkProxiedService's own default) is right for anything still
    # running on thor. The five *arr services moved to mimir (#203) pass
    # mimir's tailscale IP instead, since nginx stays on thor.
    host ? "127.0.0.1",
  }: {
    config,
    lib,
    ...
  }: let
    cfg = config.services.${service};
  in {
    imports = [
      (inputs.self.lib.mkProxiedService {
        inherit name port description icon probePath host;
        subdomain = service;
        group = "Media";
      })
    ];

    age.secrets."${service}-apikey" =
      {file = secret;}
      // lib.optionalAttrs (!dynamicUser) {
        owner = cfg.user;
        group = cfg.user;
      };

    services.${service} =
      {
        enable = true;
        # No openFirewall: reached via cloudflared -> nginx (Access-gated) or
        # the tailnet; the LAN bridge must not reach it directly.
        settings = {
          server.port = port;
          auth = {
            method = "External";
            # Deliberate, not an oversight - see #174: with the LAN opening
            # gone (closed in #182), the only unauthenticated callers left
            # are nginx on loopback (Access-gated) and soularr over docker0
            # (soularr.nix), which depends on no-auth here (its api_key is
            # disabled). Switching to "Forms" would break soularr and add a
            # password layer that Access is meant to replace, not duplicate.
            type = "DisabledForLocalAddresses";
          };
        };
        environmentFiles = [config.age.secrets."${service}-apikey".path];
      }
      // lib.optionalAttrs (dataDir != null) {inherit dataDir;};

    # dynamicUser services get "tank" via SupplementaryGroups (no static
    # user to add to extraGroups); static-user services via extraGroups.
    users.users = lib.optionalAttrs (!dynamicUser) {
      ${cfg.user}.extraGroups = ["tank"];
    };

    systemd.services.${service}.serviceConfig =
      lib.optionalAttrs dynamicUser {SupplementaryGroups = ["tank"];}
      // lib.optionalAttrs umask {UMask = lib.mkForce "0002";};
  };
}
