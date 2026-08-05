_: {
  flake.modules.nixos.intel-vaapi = {pkgs, ...}: {
    # Imported by both immich.nix and jellyfin.nix. Without an explicit key
    # the module system treats each import as a distinct module and
    # concatenates list options (e.g. hardware.graphics.extraPackages twice).
    key = "intel-vaapi-aspect";

    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-vaapi-driver # previously vaapiIntel
        libva-vdpau-driver
        libvdpau-va-gl
        intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
        vpl-gpu-rt # QSV on 11th gen or newer
        intel-media-driver # QSV up to 11th gen
      ];
    };
  };
}
