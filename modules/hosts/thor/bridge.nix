_: {
  flake.modules.nixos.thor = {lib, ...}: let
    ipAddress = "192.168.68.128";
  in {
    networking = {
      networkmanager.enable = lib.mkForce false;
      useDHCP = false;
      bridges = {
        "br0" = {
          interfaces = ["enp2s0" "enp3s0" "enp4s0" "enp5s0"];
        };
      };
      interfaces.br0.ipv4.addresses = [
        {
          address = ipAddress;
          prefixLength = 22;
        }
      ];
      defaultGateway = {
        address = "192.168.68.1";
        interface = "br0";
      };
      nameservers = ["194.242.2.2" "1.1.1.1" "8.8.8.8"];
    };

    systemd.network.networks."40-br0".routingPolicyRules = [
      {
        From = ipAddress;
        Table = "main";
        Priority = 100;
      }
    ];
  };
}
