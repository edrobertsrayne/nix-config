{inputs, ...}: {
  flake.modules.nixos.common = {pkgs, ...}: {
    imports = with inputs.self.modules.nixos; [
      avahi
      capslock
      docker
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
    ];
  };
}
