_: {
  flake.modules.nixos.thor = {
    disko.devices = {
      disk = {
        nvme0 = {
          device = "/dev/disk/by-id/nvme-SAMSUNG_MZVL8512HELU-00BTW_S7J1NX1X708010";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                size = "1G";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                };
              };
              zfs = {
                size = "100%";
                content = {
                  type = "zfs";
                  pool = "zroot";
                };
              };
            };
          };
        };
        nvme1 = {
          device = "/dev/disk/by-id/nvme-SAMSUNG_MZVL8512HELU-00BTW_S7J1NX2X726096";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                size = "1G";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot-fallback";
                };
              };
              zfs = {
                size = "100%";
                content = {
                  type = "zfs";
                  pool = "zroot";
                };
              };
            };
          };
        };
      };
      zpool = {
        zroot = {
          type = "zpool";
          mode = "mirror";
          # Deliberately unencrypted: no ZFS native encryption or LUKS
          # layer. Accepted risk for a home server - physical access or
          # disk disposal exposes data at rest, weighed against the
          # complexity of key management on a headless box with no TPM
          # unlock path here. Adding native encryption means destroying
          # and recreating this pool (backup, `zpool create -O
          # encryption=on ...`, restore), not a config edit - so it's a
          # next-clean-install item, not something to retrofit live. See
          # #181.
          rootFsOptions = {
            acltype = "posixacl";
            atime = "off";
            compression = "lz4";
            xattr = "sa";
            "com.sun:auto-snapshot" = "false";
          };
          options.ashift = "12";

          datasets = {
            srv = {
              type = "zfs_fs";
              mountpoint = "/srv";
              options."com.sun:auto-snapshot" = "true";
            };
            nix = {
              type = "zfs_fs";
              mountpoint = "/nix";
              options."com.sun:auto-snapshot" = "false";
            };
            root = {
              type = "zfs_fs";
              mountpoint = "/";
              options."com.sun:auto-snapshot" = "false";
            };
            libvirt = {
              type = "zfs_fs";
              mountpoint = "/var/lib/libvirt";
              options."com.sun:auto-snapshot" = "true";
            };
          };
        };
      };
    };
  };
}
