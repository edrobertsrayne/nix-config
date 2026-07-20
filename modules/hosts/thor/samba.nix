_: {
  flake.modules.nixos.thor = {
    services.samba = {
      enable = true;
      openFirewall = true;
      settings = {
        global = {
          "workgroup" = "WORKGROUP";
          "security" = "user";
          "guest account" = "nobody";
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
          "read only" = "no";
          "guest ok" = "yes";
        };
        "backup" = {
          "path" = "/mnt/storage/backup";
          "browseable" = "yes";
          "read only" = "no";
          "guest ok" = "yes";
        };
      };
    };

    services.samba-wsdd.enable = true;
  };
}
