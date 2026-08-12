{inputs, ...}: {
  flake = let
    inherit (inputs.self.lib) mkNixosSystem;
  in {
    nixosConfigurations.mimir = mkNixosSystem {name = "mimir";};

    modules.nixos.mimir = _: let
      # TODO: confirm this doesn't collide with the router's DHCP pool
      # before actually provisioning mimir - br0 is a /22 shared with LAN
      # DHCP clients and thor is the only other static reservation on it
      # today (modules/hosts/thor/bridge.nix). settings/mimir.nix is the
      # single source of truth for this address - every proxied service on
      # thor reads it too.
      ipAddress = inputs.self.settings.mimir.address;
      mac = "02:00:00:00:00:10";
    in {
      imports = [
        inputs.microvm.nixosModules.microvm
        inputs.self.modules.nixos.downloads
      ];

      # microvm.nix's own module sets a mkDefault hostId too, which
      # conflicts with mkNixosSystem's (modules/lib/hosts.nix) at the same
      # priority. A plain assignment outranks both mkDefaults, so this wins
      # cleanly instead of needing mkForce. Not used for anything - mimir
      # doesn't run ZFS itself - just needs to be a valid 8-hex-digit value.
      networking.hostId = "10000001";

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

        # Two volumes, not one: docker's data-root and every *arr dataDir
        # default to /srv (modules/lib/servarr.nix, mirrored from thor.nix),
        # while tailscale/systemd/NixOS's own uid-gid map (/var/lib/nixos)
        # live under /var. microvm.nix's default root is a squashfs rebuilt
        # from the Nix store on every generation - fine for /nix, but both
        # /var and /srv hold real state that must survive a VM restart
        # (mimir is a plain persistent root, not impermanent - see #203
        # decision log), so each gets its own image-backed volume instead.
        volumes = [
          {
            image = "var.img";
            mountPoint = "/var";
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

      # impermanence's own assertion: every filesystem a persisted path
      # lives on needs neededForBoot=true, same reasoning as thor's
      # "/persist".neededForBoot - here it's /var itself since that's its
      # own microvm.volumes-backed filesystem, not part of root.
      fileSystems."/var".neededForBoot = true;

      # modules/tailscale.nix is in `common` (every host gets it, including
      # mimir) and unconditionally declares
      # environment.persistence."/persist".directories = ["/var/lib/tailscale"].
      # mimir has no /persist dataset at all - it's a plain persistent root,
      # not impermanent (see the microvm.volumes comment above). Left alone,
      # that directive would still "work" syntactically but silently redirect
      # /var/lib/tailscale from the genuinely-persistent /var volume it
      # already lives on onto a bind-mount source under mimir's *ephemeral*
      # squashfs root - actively breaking tailscale's node identity across
      # restarts instead of leaving it alone. Disabling the whole "/persist"
      # root is correct here: nothing else on mimir declares a persistence
      # directive under it.
      environment.persistence."/persist".enable = false;
    };
  };
}
