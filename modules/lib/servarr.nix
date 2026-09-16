_: {
  flake.lib.mkArr = {
    service,
    port,
    dynamicUser ? false,
    umask ? true,
    dataDir ? "/srv/${service}",
    secret,
  }: {
    config,
    lib,
    ...
  }: let
    cfg = config.services.${service};
  in {
    age.secrets."${service}-apikey" =
      {file = secret;}
      // lib.optionalAttrs (!dynamicUser) {
        owner = cfg.user;
        group = cfg.user;
      };

    services.${service} =
      {
        enable = true;
        settings = {
          server.port = port;
          auth = {
            method = "External";
            type = "DisabledForLocalAddresses";
          };
        };
        environmentFiles = [config.age.secrets."${service}-apikey".path];
      }
      // lib.optionalAttrs (dataDir != null) {inherit dataDir;};

    # sabnzbd and transmission too: their completed-download dirs are meant
    # to inherit group tank via setgid (sabnzbd.nix, transmission.nix), but
    # that inheritance is unreliable over the virtiofs mount, so some dirs
    # come out group=sabnzbd or group=transmission instead. Membership in
    # all three groups means delete-after-import works regardless.
    users.users = lib.optionalAttrs (!dynamicUser) {
      ${cfg.user}.extraGroups = ["tank" "sabnzbd" "transmission"];
    };

    # dataDir lives outside /var/lib, so StateDirectory= doesn't create it, and
    # /srv is root-owned — the service cannot mkdir its own directory and dies
    # at startup. Only surfaces on a host where /srv is freshly formatted.
    systemd.tmpfiles.rules = lib.optionals (dataDir != null) [
      "d ${dataDir} 0700 ${cfg.user} ${cfg.user} -"
    ];

    systemd.services.${service}.serviceConfig =
      lib.optionalAttrs dynamicUser {SupplementaryGroups = ["tank" "sabnzbd" "transmission"];}
      // lib.optionalAttrs umask {UMask = lib.mkForce "0002";};
  };
}
