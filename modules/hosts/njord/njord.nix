{inputs, ...}: {
  flake = let
    inherit (inputs.self.lib) mkNixosSystem;
  in {
    nixosConfigurations.njord = mkNixosSystem {name = "njord";};

    modules.nixos.njord = {pkgs, ...}: let
      ipAddress = inputs.self.settings.hosts.njord.address;
      mac = "02:00:00:00:00:11";
    in {
      imports = [
        inputs.microvm.nixosModules.microvm
        inputs.self.modules.nixos.persistence
      ];

      # Dokploy's install.sh shells out to `openssl rand -hex 32` to generate
      # its Better Auth secret, with no fallback if it's missing — the script
      # only falls back to /dev/urandom/sha256sum for the Postgres password,
      # not this. Without it Dokploy silently falls back to its own default
      # auth secret (BetterAuthError in the container logs) rather than
      # failing the install outright.
      environment.systemPackages = [pkgs.openssl];

      # The microvm.nix module also sets a mkDefault hostId, which conflicts
      # with the mkDefault hostId from mkNixosSystem (modules/lib/hosts.nix) —
      # both use the same priority. A plain assignment outranks both, the same
      # way mimir.nix (modules/hosts/mimir/mimir.nix) handles it. This value
      # has no other use and only needs to be a valid 8-digit hex number.
      networking.hostId = "10000002";

      # Dokploy's UI. 80/443 are published directly by Docker (traefik's
      # `docker run -p 80:80 -p 443:443`), which bypasses nixos-fw via the
      # DOCKER-USER chain, so they need no entry here.
      networking.firewall.allowedTCPPorts = [3000];

      microvm = {
        hypervisor = "qemu";
        vcpu = 4;
        mem = 8192;

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
        # networkd must never manage Docker's links — the same footgun mimir
        # hit with podman (see the long comment in
        # modules/hosts/mimir/mimir.nix): if networkd claims a veth, Docker's
        # own bridging gets pulled out from under it. Belt-and-braces
        # alongside the MACAddress match below, which already keeps 10-eth
        # from matching these.
        "05-container" = {
          matchConfig.Name = ["veth*" "docker*" "br-*"];
          linkConfig.Unmanaged = "yes";
        };

        # Matched by MAC rather than interface name: unlike mimir (whose NIC
        # is known to enumerate as enp0s7), njord's guest NIC name isn't
        # pinned down yet, and MACAddress is immune to that while still
        # excluding Docker's own interfaces.
        "10-eth" = {
          matchConfig = {
            Type = "ether";
            MACAddress = mac;
          };
          networkConfig = {
            Address = ["${ipAddress}/22"];
            Gateway = "192.168.68.1";
            DHCP = "no";
          };
        };
      };

      # All of Dokploy's and Docker's state lives on srv.img.
      virtualisation.docker.daemon.settings.data-root = "/srv/docker";

      # Dokploy hardcodes /etc/dokploy for its config, Traefik's dynamic
      # config dir, and app volumes. Root is tmpfs on a microvm (wiped every
      # boot via the persistence model thor and mimir both use), so bind it
      # onto srv.img instead. The installer chmods this 0777 itself; the
      # tmpfiles rule just ensures the mountpoint exists first.
      systemd.tmpfiles.rules = ["d /srv/dokploy 0755 root root -"];
      fileSystems."/etc/dokploy" = {
        device = "/srv/dokploy";
        fsType = "none";
        options = ["bind"];
        depends = ["/srv"];
      };

      # Root is tmpfs (wiped every boot), so /persist's bind-mounts (SSH host
      # keys, /etc/machine-id) must win the race against systemd's own
      # first-boot machine-id generation — same reasoning as mimir and thor.
      boot.initrd.systemd.enable = true;
      fileSystems."/persist" = {
        neededForBoot = true;
        noCheck = true;
      };

      # Read-only /nix/store share, same as mimir.
      nix.optimise.automatic = false;
    };
  };
}
