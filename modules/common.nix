{inputs, ...}: {
  flake.modules.nixos.common = {pkgs, ...}: {
    # Only what every host needs, guests included. Anything a microvm guest
    # has no use for (docker, avahi, capslock, home-manager, nix-gc,
    # auto-upgrade) is imported by the hosts that want it instead.
    imports = with inputs.self.modules.nixos; [
      locale
      networking
      nix
      server
      ssh
      tailscale
      user
    ];

    environment.systemPackages = with pkgs; [
      wget
      curl
      vim
      tree
      htop
      devenv
      herdr-core
    ];
  };
}
