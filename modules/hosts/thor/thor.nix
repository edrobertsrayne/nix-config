{inputs, ...}: {
  flake = let
    inherit (inputs.self.lib) mkNixosSystem;
  in {
    nixosConfigurations.thor = mkNixosSystem {name = "thor";};

    modules.nixos.thor = {pkgs, ...}: {
      imports = with inputs.self.modules.nixos; [
        ./_hardware.nix
        (import ./_microvm-host.nix {inherit inputs;})
        ./_rollback.nix

        alertmanager
        alertmanager-ntfy
        auto-upgrade
        avahi
        bar-assistant
        bentopdf
        blackbox-exporter
        blocky
        cadvisor
        capslock
        cloudflared
        dlna
        docker
        downloads-proxy
        fancontrol
        grafana
        home-manager
        homepage
        immich
        janitarr
        jellyfin
        karakeep
        libvirt
        loki
        n8n
        navidrome
        nfs
        nginx
        nix-gc
        ntfy
        paperless
        persistence
        portainer
        prometheus
        restic
        restic-server
        samba
        searxng
        seerr
        smart
        speedtest
        user-password
        vaultwarden
        zfs
      ];

      boot = {
        loader = {
          systemd-boot = {
            enable = true;
            configurationLimit = 5;
          };
          efi = {
            canTouchEfiVariables = true;
            efiSysMountPoint = "/boot";
          };
        };
        tmp.cleanOnBoot = true;
      };

      # CPU package temperature; the guests have no thermal zones.
      services.prometheus.exporters.node.enabledCollectors = ["thermal_zone"];

      zramSwap = {
        enable = true;
        memoryPercent = 25;
        priority = 100; # first tier — compressed, in-RAM, fast
      };

      # zram alone is not a backstop: it holds compressed pages *in RAM*, so
      # when it fills there is nowhere left to evict to and the next large
      # allocation OOMs — which is what killed the 04:00 build and took
      # nix-daemon with it (#218). This gives the kernel a real second tier.
      # Not on ZFS: zvol swap deadlocks under exactly the memory pressure it
      # exists to relieve, and ZFS supports no swapfile. /mnt/ssd is ext4
      # (_hardware.nix) and is the only writable non-ZFS filesystem on thor.
      # Lower priority than zram, so zram is still used first and this only
      # takes the genuinely cold overflow. Shares a spindle with
      # /mnt/ssd/downloads — accepted trade, see docs/storage.md.
      swapDevices = [
        {
          device = "/mnt/ssd/swapfile";
          size = 16384; # MiB
          priority = 10;
        }
      ];

      users.groups.tank = {
        # Same GID as mimir's tank group — see modules/settings/storage.nix.
        gid = inputs.self.settings.storage.tankGid;
        members = ["${inputs.self.settings.user.username}"];
      };

      # Ensure tmpfiles runs after /mnt/ssd is mounted
      systemd.services.systemd-tmpfiles-setup.after = ["mnt-ssd.mount"];

      services = {
        tailscale.useRoutingFeatures = "client";

        fstrim.enable = true;
      };

      virtualisation.docker.daemon.settings = {
        data-root = "/srv/docker";
      };

      environment.systemPackages = with pkgs; [
        mergerfs
        smartmontools
        e2fsprogs
        parted
        iotop
        lm_sensors
        ncdu
        nmap
        pciutils
      ];

      fileSystems = {
        "/boot".options = ["umask=0077"];

        # See docs/storage.md ("The ZFS pool") for why this is required.
        "/persist".neededForBoot = true;

        "/mnt/storage" = {
          depends = [
            "/mnt/disk1"
          ];
          device = "/mnt/disk*";
          fsType = "mergerfs";
          options = [
            "defaults"
            "minfreespace=50G"
            "fsname=mergerfs-storage"
          ];
        };
      };
    };
  };
}
