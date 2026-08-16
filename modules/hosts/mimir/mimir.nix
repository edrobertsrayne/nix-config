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
      ];

      networking = {
        # The microvm.nix module also sets a mkDefault hostId. This conflicts with
        # the mkDefault hostId from mkNixosSystem (modules/lib/hosts.nix), because
        # both use the same priority. A plain assignment outranks both mkDefaults,
        # so this value wins without mkForce. This value has no other use. mimir
        # does not run ZFS itself. The value only needs to be a valid 8-digit hex
        # number.
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
        mem = 4096;

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

      systemd.network.networks."10-eth" = {
        matchConfig.Type = "ether";
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

      services.tailscale.extraSetFlags = [
        "--exit-node=se-sto-wg-201.mullvad.ts.net"
        "--exit-node-allow-lan-access=true"
      ];

      virtualisation.docker.daemon.settings.data-root = "/srv/docker";

      nix.optimise.automatic = false;

      fileSystems."/persist".neededForBoot = true;
    };
  };
}
