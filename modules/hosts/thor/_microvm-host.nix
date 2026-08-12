{inputs}: {
  imports = [inputs.microvm.nixosModules.host];

  microvm.vms.mimir.flake = inputs.self;
  microvm.autostart = ["mimir"];
}
