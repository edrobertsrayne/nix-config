{inputs, ...}: let
  inherit (inputs.self.settings.user) username;
in {
  flake.modules.nixos.libvirt = {pkgs, ...}: {
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;
      };
    };

    users.users.${username}.extraGroups = ["libvirtd"];

    environment.systemPackages = with pkgs; [
      virt-viewer
      virt-manager
    ];

    # No firewall opening for SPICE/VNC (5900+): tailscale0 is a trusted
    # interface (modules/tailscale.nix), so consoles are reachable from the
    # tailnet. The LAN bridge must not reach them - a guest console listening
    # on 0.0.0.0 would otherwise be open to every device on br0.

    # VM images live on their own zroot/libvirt dataset (disko.nix), already
    # survives a wipe — do not persist /var/lib/libvirt here, it would bind
    # an empty /persist directory over them. The vTPM CA is the one piece of
    # /var/lib state this aspect owns that isn't already on that dataset.
    environment.persistence."/persist".directories = ["/var/lib/swtpm-localca"];
  };
}
