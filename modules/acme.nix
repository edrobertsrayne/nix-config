{inputs, ...}: let
  inherit (inputs.self.settings) server user;
in {
  flake.modules.nixos.acme = {config, ...}: {
    age.secrets.cloudflare-dns.file = ../secrets/cloudflare-dns.age;

    security.acme = {
      acceptTerms = true;
      defaults.email = user.email;
      # lego finds the Cloudflare zone and checks propagation via SOA/TXT
      # lookups. The system resolver is blocky, whose split-horizon mapping for
      # greensroad.uk (modules/blocky.nix) answers with a fake SOA, so lego
      # looked for zone "uk." and every renewal failed. Public DNS sees the
      # real zone.
      defaults.dnsResolver = "1.1.1.1:53";
      certs.${server.domain} = {
        extraDomainNames = ["*.${server.domain}"];
        dnsProvider = "cloudflare";
        environmentFile = config.age.secrets.cloudflare-dns.path;
        inherit (config.services.nginx) group;
        reloadServices = ["nginx.service"];
      };
    };

    environment.persistence."/persist".directories = ["/var/lib/acme"];
  };
}
