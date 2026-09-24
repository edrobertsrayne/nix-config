{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.prowlarr = {
    lib,
    pkgs,
    ...
  }: {
    imports = [
      (inputs.self.lib.mkArr {
        service = "prowlarr";
        port = ports.media.prowlarr;
        secret = ../../secrets/prowlarr-apikey.age;
        dynamicUser = true;
        umask = false;

        dataDir = null;
      })
    ];

    services.flaresolverr.enable = true;

    # server.nix disables fontconfig fleet-wide; flaresolverr's headless
    # Chromium enumerates font families on every launch and Skia hard-aborts
    # (SkFontMgr_FCI::onCountFamilies) when none exist — SIGABRT crash loop,
    # confirmed live via coredumpctl and a FONTCONFIG_FILE override (#225).
    # Identical bug/fix to karakeep's browser, see 19c789b.
    fonts = {
      fontconfig.enable = lib.mkForce true;
      packages = [pkgs.noto-fonts];
    };

    systemd.services.flaresolverr.serviceConfig = {
      MemoryHigh = "768M";
      MemoryMax = "1G"; # prevent OOM causing crash loops on VM
    };
  };

  flake.modules.nixos.prowlarr-proxy = inputs.self.lib.mkProxiedService {
    name = "Prowlarr";
    subdomain = "prowlarr";
    port = ports.media.prowlarr;
    description = "Indexer manager";
    icon = "prowlarr.png";
    group = "Media";
    probePath = "/ping";
    host = inputs.self.settings.hosts.mimir.tailnetName;
  };
}
