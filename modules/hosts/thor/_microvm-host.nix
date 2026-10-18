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

  # No MemoryHigh on microvm-virtiofsd@. Its ~4 GB RSS per share looked like
  # a cache (#221) but is the guest's own RAM: virtiofsd maps the guest's
  # shared memfd, so every share's RSS repeats it. Private memory is ~1-10 MB.
  # A cap only throttled that shmem and pushed guest pages into zram. Size the
  # guests (microvm.mem) and ZFS ARC (modules/zfs.nix) instead.
}
