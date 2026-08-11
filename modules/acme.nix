{inputs, ...}: let
  inherit (inputs.self.settings) server;
in {
  flake.modules.nixos.acme = {config, ...}: {
    age.secrets.cloudflare-dns.file = ../secrets/cloudflare-dns.age;

    security.acme = {
      acceptTerms = true;
      defaults.email = "ed.rayne@gmail.com";
      certs.${server.domain} = {
        extraDomainNames = ["*.${server.domain}"];
        dnsProvider = "cloudflare";
        environmentFile = config.age.secrets.cloudflare-dns.path;
        group = "nginx";
        reloadServices = ["nginx.service"];
      };
    };

    environment.persistence."/persist".directories = ["/var/lib/acme"];
  };
}
