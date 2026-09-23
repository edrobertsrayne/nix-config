{inputs}: {
  imports = [inputs.microvm.nixosModules.host];

  microvm = {
    vms = {
      mimir = {
        # Fully-declarative: mimir's system is built as part of thor's build,
        # so `nixos-rebuild switch --flake .#thor` deploys both and restarts
        # the VM on config change. The upstream assertions forbid combining
        # this with `flake`/`updateFlake`, and nixosConfigurations.mimir stays
        # the single source of truth. `microvm -u` is obsolete in this mode.
        evaluatedConfig = inputs.self.nixosConfigurations.mimir;
        restartIfChanged = true;
      };

      njord = {
        # Same fully-declarative model as mimir, above.
        evaluatedConfig = inputs.self.nixosConfigurations.njord;
        restartIfChanged = true;
      };
    };

    autostart = ["mimir" "njord"];
  };

  # virtiofsd's page-cache-like RSS is the biggest consumer of thor's 31 GiB
  # (~13 GB across mimir's three shares and njord's one, #221) and the kernel
  # was choosing to push guest anonymous pages into zram rather than reclaim
  # it. MemoryHigh is a throttle-and-reclaim ceiling, not a kill limit: the
  # cgroup is put under reclaim pressure when it exceeds this, so the cache
  # shrinks instead of the VMs swapping. Per-instance — njord's single
  # ro-store share sits at ~0.3 GB and is unaffected.
  systemd.services."microvm-virtiofsd@".serviceConfig.MemoryHigh = "4G";
}
