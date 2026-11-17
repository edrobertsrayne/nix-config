{lib, ...}: {
  # The LAN that thor's bridge and both guests' static addresses sit on.
  options.flake.settings.network = with lib; {
    gateway = mkOption {
      type = types.str;
      default = "192.168.68.1";
    };
    prefixLength = mkOption {
      type = types.ints.between 0 32;
      default = 22;
    };
  };
}
