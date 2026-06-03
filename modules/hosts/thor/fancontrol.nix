_: {
  flake.modules.nixos.thor = {pkgs, ...}: {
    hardware.fancontrol.enable = false;

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
