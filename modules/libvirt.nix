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

    networking.firewall.allowedTCPPortRanges = [
      {
        from = 5900;
        to = 5999;
      }
    ]; # allow SPICE default and additional ports

    # VM images live on their own zroot/libvirt dataset (disko.nix), already
    # survives a wipe — do not persist /var/lib/libvirt here, it would bind
    # an empty /persist directory over them. The vTPM CA is the one piece of
    # /var/lib state this aspect owns that isn't already on that dataset.
    environment.persistence."/persist".directories = ["/var/lib/swtpm-localca"];
  };
}
