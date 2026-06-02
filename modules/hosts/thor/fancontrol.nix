_: {
  flake.modules.nixos.thor = _: {
    hardware.fancontrol = {
      enable = true;
      config = ''
        INTERVAL=10
        DEVPATH=hwmon2=devices/platform/it87.2592 hwmon4=devices/platform/coretemp.0
        DEVNAME=hwmon2=it8613 hwmon4=coretemp
        FCTEMPS=hwmon2/pwm2=hwmon4/temp1_input
        FCFANS=hwmon2/pwm2=hwmon2/fan2_input
        MINTEMP=hwmon2/pwm2=50
        MAXTEMP=hwmon2/pwm2=78
        MINSTART=hwmon2/pwm2=150
        MINSTOP=hwmon2/pwm2=100
        MINPWM=hwmon2/pwm2=115
        MAXPWM=hwmon2/pwm2=255
      '';
    };
  };
}
