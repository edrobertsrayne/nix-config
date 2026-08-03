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
      # --ssh is deliberate: tailnet peers reach sshd through Tailscale SSH,
      # authorized by tailnet ACLs (Tailscale admin console, out-of-band -
      # not managed in this repo). tailscale0 is already a trusted
      # interface below, so this doesn't widen access beyond "on the
      # tailnet"; it just adds SSO/key-free auth on top of that boundary.
      # Keep the ACL least-privilege in the dashboard. See #181.
      extraUpFlags = ["--ssh" "--accept-routes"];
    };
    networking.firewall = {
      trustedInterfaces = [config.services.tailscale.interfaceName];
      allowedUDPPorts = [config.services.tailscale.port];
      checkReversePath = "loose";
    };
  };
}
