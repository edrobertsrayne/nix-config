_: {
  # aarch64 builder for cross-building the rpi5 SD image (modules/hosts/rpi5).
  flake.modules.nixos.thor = _: {
    boot.binfmt.emulatedSystems = ["aarch64-linux"];
  };
}
