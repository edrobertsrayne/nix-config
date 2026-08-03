{inputs, ...}: let
  inherit (inputs.self.settings) user;
in {
  flake.modules.nixos.thor = {config, ...}: {
    age.secrets.samba-password.file = ../../../secrets/samba-password.age;

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
          # `media`/`music`/`downloads` keeps working. Writes are gated per
          # share below via `write list`. See #175.
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
        "downloads" = {
          "path" = "/mnt/ssd/downloads";
          "browseable" = "yes";
          # Guests keep anonymous read/browse (torrent clients + Sonos-style
          # devices depend on it); writes now require the `ed` SMB login
          # instead of being open to any guest. See #175.
          "read only" = "yes";
          "write list" = user.username;
          "guest ok" = "yes";
        };
        "backup" = {
          "path" = "/mnt/storage/backup";
          "browseable" = "yes";
          # Accepted risk, not fixed here: this tree is a Mac home-directory
          # copy (Documents, Photos, Google Drive) and anonymous LAN clients
          # can read it. Guest writes are already blocked by filesystem
          # ownership (ed:lp 0755 - guests map to `nobody`, which owns
          # neither the user nor the group), so `read only = no` here only
          # ever permitted `ed` to write, never guests. Left as unauthenticated
          # read on a single-occupant LAN. See #175.
          "read only" = "no";
          "guest ok" = "yes";
        };
      };
    };

    services.samba-wsdd.enable = true;

    # Declarative counterpart to `services.samba`'s passdb: without this,
    # the `ed` SMB login above depends on imperative `smbpasswd -a` state in
    # /var/lib/samba/private, which a rebuild-from-scratch wouldn't have.
    # Re-running `smbpasswd -a` on an existing account resets its password,
    # so the secret stays authoritative across rebuilds. See #175.
    systemd.services.samba-passdb-seed = {
      description = "Seed the Samba passdb entry for ${user.username}";
      wantedBy = ["multi-user.target"];
      after = ["samba-smbd.service"];
      requires = ["samba-smbd.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        pw=$(cat ${config.age.secrets.samba-password.path})
        printf '%s\n%s\n' "$pw" "$pw" \
          | ${config.services.samba.package}/bin/smbpasswd -s -a ${user.username}
      '';
    };
  };
}
