{inputs, ...}: let
  inherit (inputs.self.settings) ports;
  port = ports.mealie;
in {
  flake.modules.nixos.mealie = {config, ...}: {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Mealie";
        subdomain = "mealie";
        inherit port;
        group = "Productivity";
        description = "Recipe manager";
        icon = "mealie.png";
        # Public endpoint returning version info. Unverified — mealie is
        # commented out of thor.nix, so check it on activation.
        probePath = "/api/app/about";
      })
    ];

    age.secrets.mealie.file = ../secrets/mealie.age;

    services.mealie = {
      enable = true;
      inherit port;
      credentialsFile = config.age.secrets.mealie.path;
    };
  };
}
