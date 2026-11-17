{lib, ...}: {
  options.flake.settings.storage = with lib; {
    # GID of the `tank` group that owns the media and download trees. Those
    # trees are virtiofs shares from thor into mimir, and raw gid numbers
    # cross that boundary, so every host must agree on this one value.
    tankGid = mkOption {
      type = types.int;
      default = 992;
    };
  };
}
