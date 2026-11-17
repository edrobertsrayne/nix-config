{inputs, ...}: {
  flake.modules.nixos.thor = {lib, ...}: let
    ipAddress = inputs.self.settings.hosts.thor.address;
    inherit (inputs.self.settings) network;
  in {
    networking = {
      networkmanager.enable = lib.mkForce false;
      useDHCP = false;
      bridges = {
        "br0" = {
          interfaces = ["enp2s0" "enp3s0" "enp4s0" "enp5s0" "vm-mimir" "vm-njord"];
        };
      };
      interfaces.br0.ipv4.addresses = [
        {
          address = ipAddress;
          inherit (network) prefixLength;
        }
      ];
      defaultGateway = {
        address = network.gateway;
        interface = "br0";
      };
      nameservers = ["194.242.2.2" "1.1.1.1" "8.8.8.8"];
    };
  };
}
