# Some settings borrowed from Srvos
{
  flake.modules.nixos.networking = {lib, ...}: {
    networking = {
      useNetworkd = lib.mkDefault true;

      firewall = {
        enable = true;
        allowPing = true;
        logRefusedConnections = lib.mkDefault false;
      };
    };
    systemd = {
      services = {
        systemd-networkd.stopIfChanged = false;
      };
      network.wait-online.enable = false;
    };
  };
}
