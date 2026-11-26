{inputs, ...}: {
  flake = let
    inherit (inputs.self.lib) mkNixosSystem;
  in {
    nixosConfigurations.mimir = mkNixosSystem {name = "mimir";};

    modules.nixos.mimir = {lib, ...}: let
      ipAddress = inputs.self.settings.hosts.mimir.address;
      inherit (inputs.self.settings) network;
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
        # A plain assignment outranks mkNixosSystem's mkDefault, and
        # microvm.nix's own mkDefault no longer fires (machineId is null). mimir
        # runs no ZFS; the value only needs to be 8-digit hex.
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
        # Not 8192: the guest's page cache grew to fill it, and that RAM is host
        # shmem thor can only swap, never drop. Working set is ~1.7 GiB anon +
        # ~1.6 GiB tmpfs.
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
          # networkd must never manage container links: netavark enslaves each
          # veth to podman0, and a networkd .network file would drop it off the
          # bridge, cutting the container off. Scoping 10-eth to the real NIC is
          # not enough, since the 99-*-dhcp fallbacks would then match the
          # veths, so they are unmanaged here first (this file sorts before
          # both).
          matchConfig.Name = ["veth*" "podman*" "docker*" "aardvark*"];
          linkConfig.Unmanaged = "yes";
        };

        network.networks."10-eth" = {
          matchConfig = {
            Type = "ether";
            # Matched by MAC, not interface name: Type=ether also matches
            # container veths, and the name follows the guest's PCI slot, which
            # moves when the qemu device list changes.
            MACAddress = mac;
          };
          networkConfig = {
            Address = ["${ipAddress}/${toString network.prefixLength}"];
            Gateway = network.gateway;
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

        # /srv has no ordering pull on systemd-tmpfiles-setup, so rules
        # targeting /srv/* could run before the mount and land on the
        # transient root, shadowed once the mount completes.
        services.systemd-tmpfiles-setup.after = ["srv.mount"];
        tmpfiles.rules = [
          "d /srv/containers 0755 root root -"
          "d /srv/containers/storage 0700 root root -"
          "d /srv/containers/tmp 1777 root root -"
        ];
      };

      services.tailscale.extraSetFlags = [
        # By IP, not hostname: tailscaled-set runs before MagicDNS resolves
        # ("cannot resolve exit node by hostname"). This is
        # se-sto-wg-201.mullvad.ts.net.
        "--exit-node=100.84.2.120"
        "--exit-node-allow-lan-access=true"
      ];

      # tailscaled-autoconnect reports Running before the netmap holds every
      # peer, so `tailscale set --exit-node` can fail with "no node found in
      # netmap". Retry until the exit node is known.
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

      # Root is tmpfs: keep podman's storage and pull staging dir (default
      # /var/tmp) on srv.img so the image cache survives reboots.
      virtualisation.containers = {
        storage.rootful.settings.storage = {
          driver = "overlay";
          graphroot = "/srv/containers/storage";
          runroot = "/run/containers/storage";
        };
        containersConf.settings.engine.image_copy_tmp_dir = "/srv/containers/tmp";
      };

      # Same GID as thor's tank group — see modules/settings/storage.nix.
      users.groups.tank.gid = inputs.self.settings.storage.tankGid;

      fileSystems."/persist" = {
        neededForBoot = true;
        # persist.img is always cleanly unmounted on shutdown. Skipping fsck
        # removes avoidable latency before its bind-mounts (/etc/machine-id,
        # SSH host keys) must win the race against systemd's machine-id
        # setup at boot.
        noCheck = true;
      };
    };
  };
}
