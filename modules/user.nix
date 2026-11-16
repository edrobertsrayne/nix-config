{inputs, ...}: let
  inherit (inputs.self.settings) user;
in {
  flake.modules.nixos.user = {
    pkgs,
    lib,
    ...
  }: {
    users = {
      # Passwords are a separate opt-in aspect (modules/user-password.nix).
      mutableUsers = false;
      users.${user.username} = {
        isNormalUser = true;
        description = user.fullname;
        extraGroups = ["wheel" "networkmanager"];
        openssh.authorizedKeys.keys = user.sshKeys;
        packages = with pkgs; [
          vim
          git
          htop
        ];
      };
    };

    security.sudo = {
      execWheelOnly = true;
      wheelNeedsPassword = lib.mkDefault false;
      extraConfig = ''
        Defaults lecture = never
      '';
    };
  };
}
