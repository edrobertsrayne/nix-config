_: {
  flake.modules.nixos.server = {
    lib,
    pkgs,
    ...
  }: {
    systemd = {
      enableEmergencyMode = false;

      sleep.settings.Sleep = {
        AllowSuspend = "no";
        AllowHibernation = "no";
      };

      settings.Manager = {
        RuntimeWatchdogSec = lib.mkDefault "15s";
        RebootWatchdogSec = lib.mkDefault "30s";
        KExecWatchdogSec = lib.mkDefault "1m";
      };
    };

    environment = {
      variables.BROWSER = "echo";

      stub-ld.enable = false;

      systemPackages = with pkgs; [
        (lib.lowPrio gitMinimal)
        (lib.lowPrio dnsutils)
        (lib.lowPrio jq)
        (lib.lowPrio tmux)
      ];
    };

    programs.command-not-found.enable = false;

    # mkDefault: aspects that run a headless browser (karakeep, flaresolverr
    # in prowlarr.nix) need fontconfig and turn it back on.
    fonts.fontconfig.enable = lib.mkDefault false;

    documentation = {
      enable = false;
      doc.enable = false;
      info.enable = false;
      man.enable = false;
      nixos.enable = false;
    };
  };
}
