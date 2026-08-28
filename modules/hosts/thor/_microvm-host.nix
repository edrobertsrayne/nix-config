{inputs}: {
  imports = [inputs.microvm.nixosModules.host];

  microvm.vms.mimir = {
    # Fully-declarative: mimir's system is built as part of thor's build, so
    # `nixos-rebuild switch --flake .#thor` deploys both and restarts the VM
    # on config change. The upstream assertions forbid combining this with
    # `flake`/`updateFlake`, and nixosConfigurations.mimir stays the single
    # source of truth. `microvm -u` is obsolete in this mode.
    evaluatedConfig = inputs.self.nixosConfigurations.mimir;
    restartIfChanged = true;
  };
  microvm.autostart = ["mimir"];
}
