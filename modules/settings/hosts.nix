{lib, ...}: {
  options.flake.settings.hosts = with lib; {
    thor.address = mkOption {
      type = types.str;
      default = "192.168.68.128";
    };

    mimir.address = mkOption {
      type = types.str;
      default = "192.168.68.129";
    };
  };
}
