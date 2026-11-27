_: {
  flake.modules.homeManager.utilities = {
    programs.nh = {
      enable = true;
      # A bare `nh os switch` builds this GitHub flake, not the local checkout,
      # silently ignoring uncommitted edits. Pass the path: `nh os test ~/config`.
      flake = "github:edrobertsrayne/nix-config";
      clean = {
        enable = true;
        dates = "daily";
        extraArgs = "--keep 3 --keep-since 5d";
      };
    };
  };
}
