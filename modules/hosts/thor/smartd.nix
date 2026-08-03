_: {
  flake.modules.nixos.thor = _: {
    # Kept for the drive-side work, not for notification: smartd enables
    # offline data collection and attribute autosave, which is what keeps the
    # SMART attributes fresh that smartctl-exporter reads and SmartSectorErrors
    # alerts on. Its own notification paths are deliberately unused — thor is
    # headless, so wall messages have no reader; alerting goes via Prometheus.
    services.smartd = {
      enable = true;
      autodetect = true;
      notifications.test = false;
    };
  };
}
