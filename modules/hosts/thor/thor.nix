{inputs, ...}: {
  flake = let
    tunnel = "23c4423f-ec30-423b-ba18-ba18904ddb85";
    secret = ../../../secrets/cloudflare-thor.age;
    inherit (inputs.self.settings.server) domain;
  in {
    modules.nixos.thor = {
      config,
      pkgs,
      ...
    }: {
      imports = with inputs.self.modules.nixos; [
        ./_hardware.nix

        common
        nginx
        portainer
        blocky
        unbound
        media
        libvirt
        vaultwarden
        # stirling-pdf
        karakeep
        # mealie
        prometheus
        alertmanager
        alertmanager-ntfy
        grafana
        loki
        n8n
        immich
        ntfy
        code-server
        searxng
        homepage
        paperless
        joplin
        bentopdf
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
        initrd.systemd.enable = true;
        tmp.cleanOnBoot = true;
        zfs.forceImportRoot = false;
        extraModulePackages = [
          (config.boot.kernelPackages.it87.overrideAttrs (old: {
            postInstall =
              (old.postInstall or "")
              + ''
                ver=$(ls $out/lib/modules)
                mkdir -p $out/lib/modules/$ver/updates
                mv $out/lib/modules/$ver/kernel/drivers/hwmon/it87.ko \
                   $out/lib/modules/$ver/updates/it87.ko
              '';
          }))
        ];
        kernelModules = ["it87"];
        extraModprobeConfig = "options it87 ignore_resource_conflict=1";
      };
      zramSwap = {
        enable = true;
        memoryPercent = 25;
      };

      users.groups.tank.members = ["${inputs.self.settings.user.username}"];

      # Ensure tmpfiles runs after /mnt/ssd is mounted
      systemd.services.systemd-tmpfiles-setup.after = ["mnt-ssd.mount"];

      age.secrets.cloudflared.file = secret;

      services = {
        cloudflared = {
          enable = true;
          tunnels."${tunnel}" = {
            credentialsFile = config.age.secrets.cloudflared.path;
            default = "http_status:404";
            ingress = {
              "*.${domain}" = "http://127.0.0.1:80";
            };
          };
        };

        tailscale = {
          useRoutingFeatures = "client";
          extraSetFlags = [
            "--exit-node=se-sto-wg-201.mullvad.ts.net"
            "--exit-node-allow-lan-access=true"
          ];
        };

        fstrim.enable = true;
      };

      security.sudo.wheelNeedsPassword = false;

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

      fileSystems."/boot".options = ["umask=0077"];

      fileSystems."/mnt/storage" = {
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

    modules.homeManager.thor = {
      imports = with inputs.self.modules.homeManager; [
        utilities
        bash
        neovim
      ];
    };
  };
}
