_: {
  flake.modules.nixos.thor = {
    services.samba = {
      enable = true;
      # Deliberate: SMB stays reachable from the untrusted LAN bridge (br0,
      # not just tailscale0 - modules/tailscale.nix) so home devices like
      # Sonos can browse `media`/`music` without any tailnet setup. See
      # #175.
      openFirewall = true;
      settings = {
        global = {
          "workgroup" = "WORKGROUP";
          "security" = "user";
          "guest account" = "nobody";
          # Deliberate, not an oversight: unknown/blank usernames (Sonos and
          # similar appliances that don't send credentials) fall through to
          # guest rather than being rejected, so anonymous read of
          # `media`/`music` keeps working. Samba is guest-read-only now;
          # all writable access (downloads, backup) moved to NFS, gated by
          # the tailnet. See #175.
          "map to guest" = "bad user";
        };
        "media" = {
          "path" = "/mnt/storage/media";
          "browseable" = "yes";
          "read only" = "yes";
          "guest ok" = "yes";
        };
        "music" = {
          "path" = "/mnt/ssd/music";
          "browseable" = "yes";
          "read only" = "yes";
          "guest ok" = "yes";
        };
      };
    };

    services.samba-wsdd.enable = true;

    environment.persistence."/persist".directories = ["/var/lib/samba"];
  };
}
