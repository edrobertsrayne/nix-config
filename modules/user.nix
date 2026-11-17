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
        extraGroups = ["wheel"];
        openssh.authorizedKeys.keys = user.sshKeys;
        # vim and htop come from modules/common.nix.
        packages = [pkgs.git];
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
