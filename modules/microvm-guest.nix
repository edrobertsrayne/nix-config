_: {
  flake.modules.nixos.microvm-guest = {
    # thor builds and deploys both guests via microvm.vms.<n>.evaluatedConfig
    # (modules/hosts/thor/_microvm-host.nix), and /nix/store arrives as a
    # read-only virtiofs share with no nix-daemon. Guests therefore do not
    # import `nix-gc`, `auto-upgrade` or `home-manager`: nix-gc cannot unlink,
    # nixos-upgrade cannot write a flake lock, and home-manager's activation
    # cannot plant GC roots. Nothing is lost: /home is tmpfs and
    # modules/user.nix already provides ed's account and shell.

    # microvm.nix defaults machineId to a hash of the hostname and writes
    # environment.etc."machine-id" from it, so /etc/machine-id exists as a
    # static symlink before impermanence's bind-mount unit runs, and that unit
    # fails every boot ("A file already exists"). Guests are tmpfs-root, so
    # impermanence must own the file. null keeps the deterministic UUID for
    # machined/SMBIOS and only drops the /etc entry.
    microvm.machineId = null;
  };
}
