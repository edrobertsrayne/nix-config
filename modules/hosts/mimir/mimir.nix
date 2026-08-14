{inputs, ...}: {
  flake = let
    inherit (inputs.self.lib) mkNixosSystem;
  in {
    nixosConfigurations.mimir = mkNixosSystem {name = "mimir";};

    modules.nixos.mimir = {lib, ...}: let
      # TODO: confirm that this address does not collide with the router's DHCP pool.
      # Do this before you provision mimir. br0 is a /22 network shared with LAN
      # DHCP clients. thor is the only other static reservation on br0 today
      # (modules/hosts/thor/bridge.nix). settings/hosts.nix is the single source
      # of truth for this address. Every proxied service on thor reads it too.
      ipAddress = inputs.self.settings.hosts.mimir.address;
      mac = "02:00:00:00:00:10";

      # thor's br0 address (modules/hosts/thor/bridge.nix). thor is the only host
      # that the ports below allow through. modules/networking.nix treats br0 as
      # untrusted, the same as the WAN, and this rule applies to mimir too through
      # `common`. This exception is scoped to thor only, not to the whole LAN.
      thorAddress = inputs.self.settings.hosts.thor.address;

      # nginx on thor now reaches each of these ports across hosts (#203). Before,
      # loopback traffic skipped the firewall completely, because nginx ran on the
      # same host. As a result, none of these ports were ever open. soularr is not
      # in this list. Docker publishes its port and governs it with Docker's own
      # iptables rules, not this firewall chain (see downloads/soularr.nix).
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

        # networking.nix's firewall.enable = true (through `common`) blocks these
        # ports on br0 by default, the same as every other untrusted-interface
        # port on any host. extraCommands and extraStopCommands are the standard
        # NixOS method for a rule scoped to one source address. The declarative
        # allowedTCPPorts and interfaces options cannot express this: they gate
        # only by port or by whole interface, not by peer address. This rule
        # inserts the accept rule into the nixos-fw chain, right before its own
        # default-refuse jump, the same chain that the declarative options use.
        firewall = {
          extraCommands = ''
            iptables -A nixos-fw -s ${thorAddress} -p tcp -m multiport --dports ${proxiedPortsList} -j nixos-fw-accept
          '';
          extraStopCommands = ''
            iptables -D nixos-fw -s ${thorAddress} -p tcp -m multiport --dports ${proxiedPortsList} -j nixos-fw-accept 2>/dev/null || true
          '';
        };
      };

      # qemu is the only microvm.nix hypervisor backend that supports tap networking,
      # virtiofs shares, and image-backed volumes together. mimir needs all three
      # features.
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
          # The upstream documentation recommends this. Mounting the host's /nix/store
          # avoids rebuilding it into the guest's own squashfs on every generation.
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
          # This share is read-write. The *arr import process writes into the media
          # library. It does not only read from it.
          {
            tag = "media";
            source = "/mnt/storage";
            mountPoint = "/mnt/storage";
            proto = "virtiofs";
          }
        ];

        # This configuration uses two volumes, not one. This matches the split of
        # thor's own ZFS datasets (modules/hosts/thor/disko.nix: separate "persist"
        # and "srv" datasets alongside root). microvm.nix rebuilds the default root
        # as a squashfs from the Nix store on every generation, so the root is
        # already ephemeral. Unlike thor, mimir needs no equivalent of the
        # rollback-root unit (modules/hosts/thor/_rollback.nix) to get a clean root
        # back after a restart.
        #
        # The paths that need to survive a restart follow the same split as thor.
        # The small set of paths that modules/persistence.nix bind-mounts back onto
        # root (ssh host keys, machine-id, /var/lib/nixos, tailscale's identity, and
        # more) live on /persist. Docker's data-root and every *arr dataDir
        # (modules/lib/servarr.nix, mirrored from thor.nix) default to /srv.
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

      # matchConfig.Type = "ether" does not name a predictable interface and does
      # not match by MAC address. mimir has exactly one NIC, and this is the
      # pattern that the microvm.nix documentation uses for a single-interface
      # guest.
      systemd.network.networks."10-eth" = {
        matchConfig.Type = "ether";
        networkConfig = {
          Address = ["${ipAddress}/22"];
          Gateway = "192.168.68.1";
          DHCP = "no";
        };
        # This rule moves thor's old 40-br0 rule here without change. It keeps
        # return traffic for inbound P2P peers (transmission, slskd) off the
        # exit-node's routing table, so the connection does not hang.
        routingPolicyRules = [
          {
            From = ipAddress;
            Table = "main";
            Priority = 100;
          }
        ];
      };

      # This setting moved from thor.nix. This move is the whole point of #203:
      # only the download stack needs Mullvad, not every service on thor.
      services.tailscale.extraSetFlags = [
        "--exit-node=se-sto-wg-201.mullvad.ts.net"
        "--exit-node-allow-lan-access=true"
      ];

      virtualisation.docker.daemon.settings.data-root = "/srv/docker";

      # modules/nix.nix turns this on by default for anything that is not a
      # container, and this includes mimir. But /nix/store here is the ro-store
      # virtiofs share above, not a real writable filesystem to optimize with
      # hardlinks. The upstream warning says this option "doesn't do what you
      # expect" against a shared or block store.
      nix.optimise.automatic = false;

      # See docs/storage.md ("The ZFS pool") for why this is required.
      fileSystems."/persist".neededForBoot = true;
    };
  };
}
