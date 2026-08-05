_: {
  flake.modules.nixos.postgresql = {
    # Imported by both blocky.nix and immich.nix. Without an explicit key the
    # module system treats each import as a distinct module and concatenates
    # the persistence list, tripping impermanence's duplicateDirs assertion.
    key = "postgresql-aspect";
    services.postgresql.enable = true;
    environment.persistence."/persist".directories = ["/var/lib/postgresql"];
  };
}
