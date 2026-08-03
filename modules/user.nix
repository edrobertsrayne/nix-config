{inputs, ...}: let
  inherit (inputs.self.settings) user;
in {
  flake.modules.nixos.user = {
    config,
    pkgs,
    lib,
    ...
  }: {
    age.secrets = {
      user-password.file = ../secrets/user-password.age;
      root-password.file = ../secrets/root-password.age;
    };

    users = {
      mutableUsers = false;
      users.${user.username} = {
        isNormalUser = true;
        description = user.fullname;
        hashedPasswordFile = config.age.secrets.user-password.path;
        extraGroups = ["wheel" "networkmanager"];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN0EYKmro8pZDXNyT5NiBZnRGhQ/5HlTn5PJEWRawUN1"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHjO/+Q0fcuPJlilQNFfTbxG78ov3owvJW66poCTZVy4"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJdf/364Rgul97UR6vn4caDuuxBk9fUrRjfpMsa4sfam" # ed@freya
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINW5tgMzPytrfk373U9EfL5ol6No9lIelF6dL8ZYSe0B" # ed@thor
        ];
        packages = with pkgs; [
          vim
          git
          htop
        ];
      };

      # Distinct from the user hash. Kept (not locked) so the KVM console
      # stays a usable rescue path; PermitRootLogin = "no" (modules/ssh.nix)
      # keeps it off the network.
      users.root.hashedPasswordFile = config.age.secrets.root-password.path;
    };

    security.sudo = {
      execWheelOnly = true;
      wheelNeedsPassword = lib.mkDefault true;
      extraConfig = ''
        Defaults lecture = never
      '';
    };
  };
}
