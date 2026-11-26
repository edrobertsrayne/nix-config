{inputs, ...}: let
  inherit (inputs.self.lib) textfileDir;
in {
  flake.modules.nixos.speedtest = {pkgs, ...}: let
    # speedtest-go --json reports dl_speed/ul_speed in bytes per second and
    # latency/jitter in nanoseconds; packet_loss is a sent/max sequence count.
    # A failed test is data (the link is usually what broke), so it publishes
    # speedtest_success 0 and exits 0. Only a broken binary fails the unit.
    speedtest = pkgs.writeShellScript "speedtest-textfile" ''
      set -euo pipefail

      out=${textfileDir}/speedtest.prom
      tmp=$out.tmp
      now=$(${pkgs.coreutils}/bin/date +%s)

      if result=$(${pkgs.coreutils}/bin/timeout 120 ${pkgs.speedtest-go}/bin/speedtest-go --json 2>/dev/null) \
        && echo "$result" | ${pkgs.jq}/bin/jq -e '.servers[0].dl_speed' >/dev/null; then
        {
          echo "# HELP speedtest_success 1 if the last speed test completed."
          echo "# TYPE speedtest_success gauge"
          echo "speedtest_success 1"
          echo "# HELP speedtest_last_run_timestamp_seconds Unix time of the last speed test attempt."
          echo "# TYPE speedtest_last_run_timestamp_seconds gauge"
          echo "speedtest_last_run_timestamp_seconds $now"
          echo "$result" | ${pkgs.jq}/bin/jq -r '
            .servers[0] as $s
            | ($s.name | gsub("[\\\\\"]"; "")) as $name
            | "server=\"\($name)\",server_id=\"\($s.id)\"" as $l
            | "# TYPE speedtest_download_bits_per_second gauge",
              "speedtest_download_bits_per_second{\($l)} \($s.dl_speed * 8)",
              "# TYPE speedtest_upload_bits_per_second gauge",
              "speedtest_upload_bits_per_second{\($l)} \($s.ul_speed * 8)",
              "# TYPE speedtest_latency_seconds gauge",
              "speedtest_latency_seconds{\($l)} \($s.latency / 1e9)",
              "# TYPE speedtest_jitter_seconds gauge",
              "speedtest_jitter_seconds{\($l)} \($s.jitter / 1e9)",
              (if ($s.packet_loss.max // 0) > 0 then
                "# TYPE speedtest_packet_loss_ratio gauge",
                "speedtest_packet_loss_ratio{\($l)} \([0, (($s.packet_loss.max - $s.packet_loss.sent) / $s.packet_loss.max)] | max)"
              else empty end)
          '
        } > "$tmp"
      else
        {
          echo "# HELP speedtest_success 1 if the last speed test completed."
          echo "# TYPE speedtest_success gauge"
          echo "speedtest_success 0"
          echo "# HELP speedtest_last_run_timestamp_seconds Unix time of the last speed test attempt."
          echo "# TYPE speedtest_last_run_timestamp_seconds gauge"
          echo "speedtest_last_run_timestamp_seconds $now"
        } > "$tmp"
      fi

      # node-exporter will happily read a half-written file.
      mv "$tmp" "$out"
    '';
  in {
    imports = [inputs.self.modules.nixos.textfile-collector];

    systemd = {
      services.speedtest-textfile = {
        description = "Run a speed test and publish it as node-exporter textfile metrics";
        after = ["network-online.target"];
        wants = ["network-online.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = speedtest;
        };
      };

      timers.speedtest-textfile = {
        description = "Hourly internet speed test";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "hourly";
          RandomizedDelaySec = "5m";
          Persistent = true;
        };
      };
    };

    monitoring.dashboards.internet = ./dashboards/internet.json;
  };
}
