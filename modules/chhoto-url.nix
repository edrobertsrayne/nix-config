{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  port = ports.chhotoUrl;
in {
  flake.modules.nixos.chhoto-url = {config, ...}: {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Chhoto URL";
        subdomain = "go";
        inherit port;
        group = "Tools";
        description = "URL shortener";
        icon = "chhoto-url.png";
        websockets = false;
      })
    ];

    # Holds `password` and `api_key`. go.<domain> is bypassed in Cloudflare
    # Access so short links work for anyone; this password is the only gate
    # on the admin UI and API.
    age.secrets.chhoto-url.file = ../secrets/chhoto-url.age;

    services.chhoto-url = {
      enable = true;
      environmentFiles = [config.age.secrets.chhoto-url.path];
      settings = {
        inherit port;
        site_url = "https://go.${server.domain}";
        # Temporary, so browsers do not cache a redirect after a link is edited.
        redirect_method = "TEMPORARY";
        slug_style = "UID";
        slug_length = 6;
        try_longer_slugs = true;
      };
    };

    # DynamicUser: state lives under /var/lib/private.
    environment.persistence."/persist".directories = ["/var/lib/private/chhoto-url"];
  };
}
