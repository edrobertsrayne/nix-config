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
            persist = {
              type = "zfs_fs";
              mountpoint = "/persist";
              options."com.sun:auto-snapshot" = "true";
            };
            home = {
              type = "zfs_fs";
              mountpoint = "/home";
              options."com.sun:auto-snapshot" = "true";
            };
            root = {
              type = "zfs_fs";
              mountpoint = "/";
              options."com.sun:auto-snapshot" = "false";
              # Blank snapshot for the wipe-on-boot rollback (#163/#167), taken
              # at format time while the dataset is genuinely empty. Guarded
              # because disko runs postCreateHook outside its own
              # dataset-exists check, so a bare `zfs snapshot` aborts on a
              # re-run. Form matches disko's own example/zfs.nix.
              postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^zroot/root@blank$' || zfs snapshot zroot/root@blank";
            };
            libvirt = {
              type = "zfs_fs";
              mountpoint = "/var/lib/libvirt";
              options."com.sun:auto-snapshot" = "true";
            };
            microvms = {
              type = "zfs_fs";
              mountpoint = "/var/lib/microvms";
              options."com.sun:auto-snapshot" = "true";
            };
          };
        };
      };
    };
  };
}
