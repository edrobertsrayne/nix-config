{inputs, ...}: {
  flake = let
    inherit (inputs.self.lib) mkNixosSystem;
  in {
    nixosConfigurations.njord = mkNixosSystem {name = "njord";};

    modules.nixos.njord = {pkgs, ...}: let
      ipAddress = inputs.self.settings.hosts.njord.address;
      inherit (inputs.self.settings) network;
      mac = "02:00:00:00:00:11";
    in {
      imports = [
        inputs.microvm.nixosModules.microvm
        inputs.self.modules.nixos.docker
        inputs.self.modules.nixos.persistence
        inputs.self.modules.nixos.microvm-guest
      ];

      # Dokploy's install.sh needs `openssl rand -hex 32` for its auth secret,
      # with no fallback; without it Dokploy silently uses its own default
      # secret.
      environment.systemPackages = [pkgs.openssl];

      # A plain assignment outranks mkNixosSystem's mkDefault (same as
      # mimir.nix); the value only needs to be 8-digit hex.
      networking.hostId = "10000002";

      # Dokploy's UI. 80/443 are published directly by Docker (traefik's
      # `docker run -p 80:80 -p 443:443`), which bypasses nixos-fw via the
      # DOCKER-USER chain, so they need no entry here.
      networking.firewall.allowedTCPPorts = [3000];

      microvm = {
        hypervisor = "qemu";
        vcpu = 4;
        # Observed peak ~3G under normal load (Swarm + Traefik + Dokploy's
        # Postgres).
        mem = 4096;
        # free-page-reporting returns freed guest pages to thor.
        balloon = true;

        interfaces = [
          {
            type = "tap";
            id = "vm-njord";
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
            size = 65536;
          }
        ];
      };

      systemd.network.networks = {
        # networkd must never manage Docker's links: claiming a veth pulls
        # Docker's bridging out from under it (see mimir.nix).
        "05-container" = {
          matchConfig.Name = ["veth*" "docker*" "br-*"];
          linkConfig.Unmanaged = "yes";
        };

        # Matched by MAC: the guest NIC name isn't pinned, and a MAC match still
        # excludes Docker's interfaces.
        "10-eth" = {
          matchConfig = {
            Type = "ether";
            MACAddress = mac;
          };
          networkConfig = {
            Address = ["${ipAddress}/${toString network.prefixLength}"];
            Gateway = network.gateway;
            DHCP = "no";
          };
        };
      };

      virtualisation.docker.daemon.settings.data-root = "/srv/docker";

      # Dokploy hardcodes /etc/dokploy and root is tmpfs, so bind it onto
      # srv.img. The installer chmods it 0777; the tmpfiles rule only ensures
      # the mountpoint exists.
      systemd.tmpfiles.rules = ["d /srv/dokploy 0755 root root -"];
      fileSystems."/etc/dokploy" = {
        device = "/srv/dokploy";
        fsType = "none";
        options = ["bind"];
        depends = ["/srv"];
      };

      fileSystems."/persist" = {
        neededForBoot = true;
        noCheck = true;
      };
    };
  };
}
