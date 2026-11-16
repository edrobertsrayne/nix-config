_: {
  flake.modules.nixos.microvm-guest = {
    # thor builds and deploys both guests via
    # microvm.vms.<n>.evaluatedConfig (modules/hosts/thor/_microvm-host.nix),
    # and /nix/store arrives as a read-only virtiofs share with no nix-daemon
    # behind it. Guests therefore do not import the `nix-gc`, `auto-upgrade`
    # or `home-manager` aspects: nix-gc cannot unlink, nixos-upgrade cannot
    # write a flake lock (#219), and home-manager's activation cannot plant
    # GC roots (#211). Nothing is lost by skipping Home Manager: /home is
    # tmpfs and not persisted, and modules/user.nix already provides ed's
    # account and shell.

    # microvm.nix defaults machineId to a hash of the hostname and writes
    # environment.etc."machine-id" from it, so /etc/machine-id exists as a
    # static symlink before impermanence's bind-mount unit runs and the unit
    # fails "A file already exists at /etc/machine-id!" every boot. Both
    # guests are tmpfs-root, so impermanence must own the file. null keeps
    # the deterministic UUID for machined/SMBIOS and only drops the /etc
    # entry. See #220.
    microvm.machineId = null;
  };
}
