{inputs, ...}: {
  flake = let
    inherit (inputs.self.lib) mkNixosSystem;
  in {
    nixosConfigurations.mimir = mkNixosSystem {name = "mimir";};

    modules.nixos.mimir = {lib, ...}: let
      # TODO: confirm this doesn't collide with the router's DHCP pool
      # before actually provisioning mimir - br0 is a /22 shared with LAN
      # DHCP clients and thor is the only other static reservation on it
      # today (modules/hosts/thor/bridge.nix). settings/hosts.nix is the
      # single source of truth for this address - every proxied service on
      # thor reads it too.
      ipAddress = inputs.self.settings.hosts.mimir.address;
      mac = "02:00:00:00:00:10";

      # thor's br0 address (modules/hosts/thor/bridge.nix) - the only host
      # allowed through the ports below. modules/networking.nix (in `common`,
      # so it applies to mimir too) treats br0 as untrusted, same as the WAN;
      # this is the one exception, scoped to thor specifically rather than
      # opened to the whole LAN.
      thorAddress = inputs.self.settings.hosts.thor.address;

      # nginx on thor reaches each of these cross-host now (#203) - loopback
      # traffic used to skip the firewall entirely when nginx was same-host,
      # so none of these were ever opened. soularr isn't here: its port is
      # Docker-published, governed by Docker's own iptables rules instead of
      # this chain (see media/soularr.nix).
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
        # microvm.nix's own module sets a mkDefault hostId too, which
        # conflicts with mkNixosSystem's (modules/lib/hosts.nix) at the same
        # priority. A plain assignment outranks both mkDefaults, so this
        # wins cleanly instead of needing mkForce. Not used for anything -
        # mimir doesn't run ZFS itself - just needs to be a valid
        # 8-hex-digit value.
        hostId = "10000001";

        # networking.nix's firewall.enable=true (via `common`) blocks these
        # by default on br0, same as every other untrusted-interface port on
        # any host. extraCommands/extraStopCommands is the standard NixOS
        # escape hatch for a source-scoped rule the declarative
        # allowedTCPPorts/interfaces options can't express (those only gate
        # by port or by whole interface, not by peer address) - this inserts
        # the accept rule into nixos-fw right before its own default-refuse
        # jump, same chain the declarative options populate.
        firewall = {
          extraCommands = ''
            iptables -A nixos-fw -s ${thorAddress} -p tcp -m multiport --dports ${proxiedPortsList} -j nixos-fw-accept
          '';
          extraStopCommands = ''
            iptables -D nixos-fw -s ${thorAddress} -p tcp -m multiport --dports ${proxiedPortsList} -j nixos-fw-accept 2>/dev/null || true
          '';
        };
      };

      # qemu: the only microvm.nix hypervisor backend that supports tap
      # networking, virtiofs shares and image-backed volumes together -
      # mimir needs all three.
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
          # Recommended by upstream docs: mounting the host's /nix/store
          # avoids rebuilding it into the guest's own squashfs on every
          # generation.
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
          # Read-write: *arr import needs to write into the media library,
          # not just read from it.
          {
            tag = "media";
            source = "/mnt/storage";
            mountPoint = "/mnt/storage";
            proto = "virtiofs";
          }
        ];

        # Two volumes, not one - same split as thor's own ZFS datasets
        # (modules/hosts/thor/disko.nix: separate "persist" and "srv"
        # datasets alongside root). microvm.nix's default root is a squashfs
        # rebuilt from the Nix store on every generation, so it's already
        # ephemeral by construction - unlike thor, mimir needs no equivalent
        # of the rollback-root unit (modules/hosts/thor/_rollback.nix) to get
        # a clean root back on restart.
        #
        # What does need to survive a restart is split the same way as
        # thor: the small set of paths modules/persistence.nix bind-mounts
        # back onto root (ssh host keys, machine-id, /var/lib/nixos,
        # tailscale's identity, ...) live on /persist, while docker's
        # data-root and every *arr dataDir (modules/lib/servarr.nix,
        # mirrored from thor.nix) default to /srv.
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

      # matchConfig.Type = "ether" (not a named/predictable interface, and
      # not MAC-matched) because mimir has exactly one NIC and this is the
      # pattern microvm.nix's own docs use for a single-interface guest.
      systemd.network.networks."10-eth" = {
        matchConfig.Type = "ether";
        networkConfig = {
          Address = ["${ipAddress}/22"];
          Gateway = "192.168.68.1";
          DHCP = "no";
        };
        # thor's old 40-br0 rule, moved here verbatim: keeps return traffic
        # for inbound P2P peers (transmission/slskd) off the exit-node's
        # routing table so the connection doesn't hang.
        routingPolicyRules = [
          {
            From = ipAddress;
            Table = "main";
            Priority = 100;
          }
        ];
      };

      # Moved from thor.nix - this is the whole point of #203: only the
      # download stack pays for Mullvad, not every service on thor.
      services.tailscale.extraSetFlags = [
        "--exit-node=se-sto-wg-201.mullvad.ts.net"
        "--exit-node-allow-lan-access=true"
      ];

      virtualisation.docker.daemon.settings.data-root = "/srv/docker";

      # modules/nix.nix defaults this on for anything that isn't a container,
      # which includes mimir - but /nix/store here is the ro-store virtiofs
      # share above, not a real writable filesystem to hardlink-optimise.
      # Upstream's own warning: "doesn't do what you expect" against a
      # shared/block store.
      nix.optimise.automatic = false;

      # Same reasoning as thor.nix's "/persist".neededForBoot: stage-2
      # activation reads /var/lib/nixos before systemd mounts local
      # filesystems, and impermanence asserts neededForBoot on every
      # persistent store.
      fileSystems."/persist".neededForBoot = true;
    };
  };
}
