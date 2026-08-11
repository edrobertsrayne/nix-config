{inputs, ...}: let
  inherit (inputs.self.settings) server user;
in {
  flake.modules.nixos.acme = {config, ...}: {
    age.secrets.cloudflare-dns.file = ../secrets/cloudflare-dns.age;

    security.acme = {
      acceptTerms = true;
      defaults.email = user.email;
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
