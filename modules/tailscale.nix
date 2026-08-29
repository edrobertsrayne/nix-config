_: {
  flake.modules.nixos.tailscale = {
    pkgs,
    config,
    ...
  }: {
    age.secrets = {
      tailscale.file = ../secrets/tailscale.age;
    };
    environment.systemPackages = with pkgs; [tailscale];
    services.tailscale = {
      enable = true;
      authKeyFile = config.age.secrets.tailscale.path;
      extraUpFlags = ["--ssh"];
    };
    networking.firewall = {
      trustedInterfaces = [config.services.tailscale.interfaceName];
      allowedUDPPorts = [config.services.tailscale.port];
      checkReversePath = "loose";
    };

    environment.persistence."/persist".directories = ["/var/lib/tailscale"];
  };
}
