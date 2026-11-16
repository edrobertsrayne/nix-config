_: {
  flake.modules.nixos.fancontrol = {
    config,
    pkgs,
    ...
  }: {
    hardware.fancontrol.enable = false;

    # The IT8613 Super I/O chip needs the out-of-tree it87 driver, which must
    # shadow the in-tree module of the same name (hence updates/).
    boot = {
      extraModulePackages = [
        (config.boot.kernelPackages.it87.overrideAttrs (old: {
          postInstall =
            (old.postInstall or "")
            + ''
              ver=$(ls $out/lib/modules)
              mkdir -p $out/lib/modules/$ver/updates
              mv $out/lib/modules/$ver/kernel/drivers/hwmon/it87.ko \
                 $out/lib/modules/$ver/updates/it87.ko
            '';
        }))
      ];
      kernelModules = ["it87"];
      extraModprobeConfig = "options it87 ignore_resource_conflict=1";
    };

    systemd.services.fancontrol = {
      description = "software fan control";
      documentation = ["man:fancontrol(8)"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Restart = "on-failure";
        ExecStartPre = let
          gen = pkgs.writeShellScript "fancontrol-gen" ''
            set -euo pipefail
            pwm="" tmp=""
            for h in /sys/class/hwmon/hwmon*; do
              n=$(cat "$h/name" 2>/dev/null || true)
              case "$n" in
                it8613)  pwm=$(basename "$h") ;;
                coretemp) tmp=$(basename "$h") ;;
              esac
            done
            if [ -z "$pwm" ] || [ -z "$tmp" ]; then
              echo "fancontrol-gen: it8613 or coretemp not found" >&2
              exit 1
            fi
            printf '%s\n' \
              "INTERVAL=10" \
              "DEVPATH=$pwm=devices/platform/it87.2592 $tmp=devices/platform/coretemp.0" \
              "DEVNAME=$pwm=it8613 $tmp=coretemp" \
              "FCTEMPS=$pwm/pwm2=$tmp/temp1_input" \
              "FCFANS=$pwm/pwm2=$pwm/fan2_input" \
              "MINTEMP=$pwm/pwm2=50" \
              "MAXTEMP=$pwm/pwm2=78" \
              "MINSTART=$pwm/pwm2=150" \
              "MINSTOP=$pwm/pwm2=100" \
              "MINPWM=$pwm/pwm2=100" \
              "MAXPWM=$pwm/pwm2=255" \
              > /run/fancontrol.conf
          '';
        in "${gen}";
        ExecStart = "${pkgs.lm_sensors}/bin/fancontrol /run/fancontrol.conf";
      };
    };
  };
}
