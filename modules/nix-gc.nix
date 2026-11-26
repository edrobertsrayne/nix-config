_: {
  # Opt-in, not part of `common`: a microvm guest mounts thor's /nix/store
  # read-only, so nix-gc cannot unlink there and fails on every run.
  flake.modules.nixos.nix-gc = {
    lib,
    config,
    ...
  }: {
    nix = {
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 7d";
      };

      optimise.automatic = lib.mkDefault (!config.boot.isContainer);
    };

    systemd.services.nix-gc.serviceConfig = {
      CPUSchedulingPolicy = lib.mkDefault "batch";
      IOSchedulingClass = lib.mkDefault "idle";
      IOSchedulingPriority = lib.mkDefault 7;
    };
  };
}
