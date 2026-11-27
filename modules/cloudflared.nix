{inputs, ...}: let
  inherit (inputs.self.settings.server) domain;
  tunnel = "23c4423f-ec30-423b-ba18-ba18904ddb85";
in {
  # The only public way in: an outbound tunnel to Cloudflare that forwards every
  # name under the domain to nginx on loopback, behind Cloudflare Access.
  flake.modules.nixos.cloudflared = {config, ...}: {
    age.secrets.cloudflared.file = ../secrets/cloudflare-thor.age;

    services.cloudflared = {
      enable = true;
      tunnels."${tunnel}" = {
        credentialsFile = config.age.secrets.cloudflared.path;
        default = "http_status:404";
        ingress = {
          "*.${domain}" = "http://127.0.0.1:80";
        };
      };
    };
  };
}
