{inputs, ...}: {
  flake = let
    inherit (inputs.self.lib) mkNixosSystem;
  in {
    nixosConfigurations.mimir = mkNixosSystem {name = "mimir";};

    modules.nixos.mimir = {lib, ...}: let
      ipAddress = inputs.self.settings.hosts.mimir.address;
      mac = "02:00:00:00:00:10";
      thorAddress = inputs.self.settings.hosts.thor.address;

      proxiedPorts = with inputs.self.settings.ports.media; [
        sonarr
        radarr
        lidarr
        bazarr
        prowlarr
        sabnzbd
        transmission
        slskd
      ];
      proxiedPortsList = lib.concatMapStringsSep "," toString proxiedPorts;
    in {
      imports = [
        inputs.microvm.nixosModules.microvm
        inputs.self.modules.nixos.downloads
        inputs.self.modules.nixos.persistence
        inputs.self.modules.nixos.microvm-guest
      ];

      networking = {
        # The microvm.nix module also sets a mkDefault hostId, conditional on
        # microvm.machineId != null — set to null by the microvm-guest aspect
        # (#220), so that mkDefault no longer fires here. A plain assignment
        # still outranks mkNixosSystem's own mkDefault (modules/lib/hosts.nix)
        # regardless. This value has no other use. mimir does not run ZFS
        # itself. The value only needs to be a valid 8-digit hex number.
        hostId = "10000001";

        firewall = {
          extraCommands = ''
            iptables -A nixos-fw -s ${thorAddress} -p tcp -m multiport --dports ${proxiedPortsList} -j nixos-fw-accept
          '';
          extraStopCommands = ''
            iptables -D nixos-fw -s ${thorAddress} -p tcp -m multiport --dports ${proxiedPortsList} -j nixos-fw-accept 2>/dev/null || true
          '';
        };
      };

      microvm = {
        hypervisor = "qemu";
        vcpu = 2;
        # Was 8192, all of which the guest used: its page cache grew to fill
        # it, and that RAM is host shmem that thor can only swap, never drop
        # (#221). Working set is ~1.7 GiB anon + ~1.6 GiB tmpfs.
        mem = 5120;
        # Returns pages the guest frees to thor (free-page-reporting).
        balloon = true;

        interfaces = [
          {
            type = "tap";
            id = "vm-mimir";
            inherit mac;
          }
        ];

        shares = [
          {
            tag = "ro-store";
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
            proto = "virtiofs";
          }
          {
            tag = "downloads";
            source = "/mnt/ssd/downloads";
            mountPoint = "/mnt/ssd/downloads";
            proto = "virtiofs";
          }

          {
            tag = "media";
            source = "/mnt/storage";
            mountPoint = "/mnt/storage";
            proto = "virtiofs";
          }
        ];

        volumes = [
          {
            image = "persist.img";
            mountPoint = "/persist";
            size = 4096;
          }
          {
            image = "srv.img";
            mountPoint = "/srv";
            size = 28672;
          }
        ];
      };

      systemd = {
        network.networks."05-container" = {
          # networkd must never manage container links. netavark enslaves each
          # container veth to podman0; a few seconds later networkd would
          # configure the veth with a .network file, which drops it off the
          # bridge — the container keeps eth0 but loses all reachability
          # (observed 2026-08-28: soularr unreachable from thor, and unable to
          # reach lidarr/slskd, on every boot since 2026-08-26). Scoping
          # 10-eth below to the real NIC alone is not enough: the 99-*-dhcp
          # fallback files would then match the veths instead, so they are
          # explicitly unmanaged here first (this file sorts before both).
          matchConfig.Name = ["veth*" "podman*" "docker*" "aardvark*"];
          linkConfig.Unmanaged = "yes";
        };

        network.networks."10-eth" = {
          matchConfig = {
            Type = "ether";
            # Matched by MAC, not interface name: Type=ether alone also
            # matches container veths (their devtype is ether), and networkd
            # managing those breaks podman networking — see the 05-container
            # block above. The name follows the guest's PCI slot, which moved
            # (enp0s7 -> enp0s8) when the qemu device list changed, dropping
            # mimir onto the DHCP fallback (#236).
            MACAddress = mac;
          };
          networkConfig = {
            Address = ["${ipAddress}/22"];
            Gateway = "192.168.68.1";
            DHCP = "no";
          };
          routingPolicyRules = [
            {
              From = ipAddress;
              Table = "main";
              Priority = 100;
            }
          ];
        };

        services.systemd-tmpfiles-setup.after = ["srv.mount"];
        tmpfiles.rules = [
          "d /srv/containers 0755 root root -"
          "d /srv/containers/storage 0700 root root -"
          "d /srv/containers/tmp 1777 root root -"
        ];
      };

      services.tailscale.extraSetFlags = [
        # By IP, not hostname: tailscaled-set runs before Tailscale can
        # resolve MagicDNS names and fails with "cannot resolve exit node by
        # hostname while Tailscale is starting up". This is
        # se-sto-wg-201.mullvad.ts.net.
        "--exit-node=100.84.2.120"
        "--exit-node-allow-lan-access=true"
      ];

      # tailscaled-autoconnect reports Running before the netmap holds every
      # peer, so `tailscale set --exit-node=<ip>` can fail with "no node found
      # in netmap" (#240). Retry until the exit node is known.
      systemd.services.tailscaled-set = {
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "5s";
        };
        unitConfig = {
          StartLimitIntervalSec = 120;
          StartLimitBurst = 10;
        };
      };

      virtualisation.docker.daemon.settings.data-root = "/srv/docker";

      # Root is tmpfs, so podman's default graphroot would lose the image
      # cache every boot and force a Docker Hub pull (#234). Keep storage and
      # the pull staging dir (default /var/tmp, also tmpfs) on srv.img.
      virtualisation.containers = {
        storage.settings.storage = {
          driver = "overlay";
          graphroot = "/srv/containers/storage";
          runroot = "/run/containers/storage";
        };
        containersConf.settings.engine.image_copy_tmp_dir = "/srv/containers/tmp";
      };

      # GID must match thor's tank group (modules/hosts/thor/thor.nix) —
      # /mnt/ssd/downloads and /mnt/storage are virtiofs shares from thor, so
      # raw uid/gid numbers cross that boundary.
      users.groups.tank.gid = 992;

      # /srv (srv.img) has no ordering pull on systemd-tmpfiles-setup by
      # default, so rules targeting /srv/* (e.g. transmission's home dir,
      # modules/downloads/transmission.nix) can run before /srv is mounted —
      # they then land on the transient root and get shadowed once the mount
      # completes. Same fix thor applies for /mnt/ssd (modules/hosts/thor/thor.nix).
      # Ordered in the systemd block above.

      fileSystems."/persist" = {
        neededForBoot = true;
        # persist.img is a small virtio-attached image that's always cleanly
        # unmounted on shutdown; skipping fsck removes the one big, avoidable
        # chunk of latency between virtio-blk attach and the mount completing
        # — see the machine-id race note below.
        noCheck = true;
      };

      # Root is tmpfs (wiped every boot), so /persist's bind-mounts (SSH host
      # keys, /etc/machine-id) must win the race against systemd's own
      # first-boot machine-id generation. That only happens reliably when the
      # persistence module's units run inside initrd, alongside thor
      # (modules/hosts/thor/thor.nix) which already does this for the same
      # reason. On mimir specifically, /persist sits on a virtio-attached
      # image (vs. thor's already-imported ZFS pool), so the mount is slower
      # to become available in initrd — noCheck above narrows that gap.
      boot.initrd.systemd.enable = true;
    };
  };
}
