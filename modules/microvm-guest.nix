_: {
  flake.modules.nixos.microvm-guest = {lib, ...}: {
    # thor builds and deploys both guests via
    # microvm.vms.<n>.evaluatedConfig (modules/hosts/thor/_microvm-host.nix),
    # and /nix/store arrives as a read-only virtiofs share with no nix-daemon
    # behind it. The fleet defaults in modules/nix.nix (imported by `common`)
    # therefore fail on every run here: nix-gc cannot unlink, and
    # nixos-upgrade cannot write a flake lock. mkForce because nix.nix sets
    # both unconditionally. See #219.
    nix.gc.automatic = lib.mkForce false;
    system.autoUpgrade.enable = lib.mkForce false;
    nix.optimise.automatic = lib.mkForce false;

    # microvm.nix defaults machineId to a hash of the hostname and writes
    # environment.etc."machine-id" from it, so /etc/machine-id exists as a
    # static symlink before impermanence's bind-mount unit runs and the unit
    # fails "A file already exists at /etc/machine-id!" every boot. Both
    # guests are tmpfs-root, so impermanence must own the file. null keeps
    # the deterministic UUID for machined/SMBIOS and only drops the /etc
    # entry. See #220.
    microvm.machineId = null;

    # home-manager's activation calls `nix-store --realise --add-root` to
    # plant GC roots, as user ed, which needs a writable /nix/var or a
    # nix-daemon — neither exists here, so home-manager-ed.service fails
    # every boot with `creating directory "/nix/var/nix/temproots":
    # Permission denied` (#211). Nothing is lost: /home is tmpfs and not
    # persisted, so HM's dotfiles would be wiped at the next boot anyway,
    # and modules/user.nix already provides ed's account and shell.
    # mkForce because mkNixosSystem (modules/lib/hosts.nix) imports the
    # home-manager aspect for every host.
    home-manager.users = lib.mkForce {};
  };
}
