{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.unbound = _: {
    services.unbound = {
      enable = true;
      settings = {
        server = {
          interface = ["127.0.0.1"];
          port = ports.unbound;
          access-control = ["127.0.0.0/8 allow"];
          hide-identity = true;
          hide-version = true;
          harden-glue = true;
          harden-dnssec-stripped = true;
          use-caps-for-id = false;
          prefetch = true;
          qname-minimisation = true;
        };
        forward-zone = [
          {
            name = ".";
            forward-tls-upstream = "yes";
            forward-addr = [
              "1.1.1.1@853#one.one.one.one"
              "1.0.0.1@853#one.one.one.one"
            ];
          }
        ];
      };
    };
  };
}
