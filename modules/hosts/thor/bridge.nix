_: {
  flake.modules.nixos.thor = {lib, ...}: let
    ipAddress = "192.168.68.128";
  in {
    networking = {
      networkmanager.enable = lib.mkForce false;
      useDHCP = false;
      bridges = {
        # vm-mimir: microvm.nix's tap interface for the mimir guest
        # (modules/hosts/mimir/mimir.nix) - puts it directly on the LAN,
        # same as the physical NICs.
        "br0" = {
          interfaces = ["enp2s0" "enp3s0" "enp4s0" "enp5s0" "vm-mimir"];
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

    # No exit-node table on thor to bypass any more (#203 moved Mullvad's
    # exit node to mimir), so the 40-br0 routingPolicyRules bypass this file
    # used to carry is gone too.
  };
}
