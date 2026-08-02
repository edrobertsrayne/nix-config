{inputs, ...}: let
  inherit (inputs.self.settings.user) username;
in {
  flake.modules.nixos.nix = {
    lib,
    config,
    ...
  }: {
    nix = {
      enable = true;
      channel.enable = false;

      settings = {
        experimental-features = ["nix-command" "flakes"];
        warn-dirty = false;
        trusted-users = ["root" "${username}" "@wheel"];
        substituters = [
          "https://cache.nixos.org"
          "https://nix-community.cachix.org"
        ];
        trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
        connect-timeout = lib.mkDefault 5;
        fallback = true;
        log-lines = lib.mkDefault 25;
        min-free = lib.mkDefault (512 * 1024 * 1024);
        max-free = lib.mkDefault (3000 * 1024 * 1024);
        builders-use-substitutes = true;
      };

      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 7d";
      };

      optimise.automatic = lib.mkDefault (!config.boot.isContainer);

      daemonCPUSchedPolicy = lib.mkDefault "batch";
      daemonIOSchedClass = lib.mkDefault "idle";
      daemonIOSchedPriority = lib.mkDefault 7;
    };

    systemd.services = {
      nix-daemon.serviceConfig.OOMScoreAdjust = lib.mkDefault 250;
      nix-gc.serviceConfig = {
        CPUSchedulingPolicy = lib.mkDefault "batch";
        IOSchedulingClass = lib.mkDefault "idle";
        IOSchedulingPriority = lib.mkDefault 7;
      };
    };

    system.autoUpgrade = {
      enable = true;
      flake = "github:edrobertsrayne/nix-config";
      flags = [];
      dates = "04:00";
      allowReboot = true;
    };

    nixpkgs.config.allowUnfree = true;
  };
}
