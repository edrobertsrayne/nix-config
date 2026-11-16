{inputs, ...}: let
  inherit (inputs.self.settings.user) username;
in {
  # Opt-in, not part of `user`: both hashes are agenix secrets, and a host
  # can only use them if its host key is a recipient of them in
  # secrets/secrets.nix. The microvm guests are not, so they declared these
  # secrets, failed to decrypt them, and ran with both accounts locked
  # anyway. A host without this aspect is key-only by design: ed logs in by
  # SSH key and sudo needs no password (modules/user.nix).
  flake.modules.nixos.user-password = {config, ...}: {
    age.secrets = {
      user-password.file = ../secrets/user-password.age;
      root-password.file = ../secrets/root-password.age;
    };

    users.users = {
      ${username}.hashedPasswordFile = config.age.secrets.user-password.path;

      # Distinct from the user hash. Kept (not locked) so the KVM console
      # stays a usable rescue path; PermitRootLogin = "no" (modules/ssh.nix)
      # keeps it off the network.
      root.hashedPasswordFile = config.age.secrets.root-password.path;
    };
  };
}
