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
  }: {
    config,
    lib,
    ...
  }: let
    cfg = config.services.${service};
  in {
    imports = [
      (inputs.self.lib.mkProxiedService {
        inherit name port description icon;
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

    services.${service} = {
      enable = true;
      dataDir = "/srv/${service}";
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
    };

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
