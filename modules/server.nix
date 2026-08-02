_: {
  flake.modules.nixos.server = {
    lib,
    pkgs,
    ...
  }: {
    systemd = {
      # Headless server: keep booting even on failure
      enableEmergencyMode = false;

      # Servers don't sleep
      sleep.settings.Sleep = {
        AllowSuspend = "no";
        AllowHibernation = "no";
      };

      # Hardware watchdog: force reboot on hang
      settings.Manager = {
        RuntimeWatchdogSec = lib.mkDefault "15s";
        RebootWatchdogSec = lib.mkDefault "30s";
        KExecWatchdogSec = lib.mkDefault "1m";
      };
    };

    environment = {
      # Print URLs rather than opening a browser
      variables.BROWSER = "echo";

      stub-ld.enable = false;

      # srvos default server packages
      systemPackages = with pkgs; [
        (lib.lowPrio gitMinimal)
        (lib.lowPrio dnsutils)
        (lib.lowPrio jq)
        (lib.lowPrio tmux)
      ];
    };

    programs.command-not-found.enable = false;

    fonts.fontconfig.enable = false;

    documentation = {
      enable = false;
      doc.enable = false;
      info.enable = false;
      man.enable = false;
      nixos.enable = false;
    };
  };
}
