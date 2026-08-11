{inputs, ...}: let
  inherit (inputs.self.settings) user;
in {
  # Bootstrap image only - no agenix/impermanence, so this does NOT use
  # flake.lib.mkNixosSystem (which pulls `common` -> agenix-backed user
  # passwords + tailscale authkey). Replace with a proper host once the Pi
  # is confirmed working; see docs/raspberry-pi.md.
  flake.nixosConfigurations.rpi5 = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = [
      inputs.self.modules.nixos.home-manager
      inputs.self.modules.nixos.avahi
      inputs.self.modules.nixos.locale
      inputs.self.modules.nixos.capslock
      (
        {
          pkgs,
          lib,
          modulesPath,
          ...
        }: {
          imports = [(modulesPath + "/installer/sd-card/sd-image-aarch64.nix")];

          nixpkgs.hostPlatform = "aarch64-linux";
          # claude-code (pulled in via home-manager's `utilities`) is unfree.
          # modules/nix.nix normally sets this but isn't imported here.
          nixpkgs.config.allowUnfree = true;

          system.stateVersion = "25.05";

          nix.settings.experimental-features = ["nix-command" "flakes"];

          # profiles/base.nix (pulled in by sd-image-aarch64.nix) enables ZFS
          # by default; the Pi has no pool and it would pull in a kernel
          # module build for nothing.
          boot.supportedFilesystems.zfs = lib.mkForce false;

          environment.systemPackages = with pkgs; [wget curl vim tree htop devenv];

          users.users = {
            ed = {
              isNormalUser = true;
              description = user.fullname;
              extraGroups = ["wheel"];
              openssh.authorizedKeys.keys = user.sshKeys;
            };
            # Rescue path if the normal user is broken.
            root.openssh.authorizedKeys.keys = user.sshKeys;
          };

          # No password material exists on this bootstrap image (no agenix),
          # so without these an HDMI console is a hard lockout. Drop both
          # once the real host config with agenix-backed passwords lands.
          security.sudo.wheelNeedsPassword = false;

          services = {
            openssh = {
              enable = true;
              settings.PasswordAuthentication = false;
            };

            getty.autologinUser = "ed";

            tailscale = {
              enable = true;
              authKeyFile = "/boot/firmware/tailscale.key";
              extraUpFlags = ["--ssh"];
            };
          };

          # sd-image.nix mounts this noauto; the Tailscale auth key and Wi-Fi
          # config below are read from here and must be available before
          # tailscaled-autoconnect and wpa_supplicant start. `options` is a
          # listOf str and merges by concatenation, so mkForce is required to
          # actually drop "noauto".
          fileSystems."/boot/firmware".options = lib.mkForce ["nofail"];

          networking = {
            hostName = "rpi5";
            firewall = {
              trustedInterfaces = ["tailscale0"];
              allowedTCPPorts = [22];
            };
            # wpa_supplicant.conf syntax; must exist even if empty (ethernet
            # only) - systemd fails a unit whose bind-mounted source is
            # missing.
            wireless = {
              enable = true;
              extraConfigFiles = ["/boot/firmware/wifi.conf"];
            };
          };
        }
      )
    ];
  };
}
