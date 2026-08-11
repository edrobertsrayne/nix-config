{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.alertmanager = _: {
    services.prometheus = {
      alertmanager = {
        enable = true;
        port = ports.alertmanager;
        # Disable cluster mode — single node, no mesh port needed
        extraFlags = ["--cluster.listen-address="];
        configuration = {
          route = {
            receiver = "ntfy";
            group_by = ["alertname" "instance" "severity"];
            group_wait = "30s";
            group_interval = "5m";
            repeat_interval = "12h";
            routes = [
              {
                matchers = ["severity = critical"];
                receiver = "ntfy";
                repeat_interval = "4h";
              }
            ];
          };
          receivers = [
            {
              name = "ntfy";
              webhook_configs = [
                {
                  url = "http://127.0.0.1:${toString ports.alertmanagerNtfy}/hook";
                  send_resolved = true;
                }
              ];
            }
          ];
          inhibit_rules = [
            {
              source_matchers = ["severity = critical"];
              target_matchers = ["severity = warning"];
              equal = ["alertname" "instance"];
            }
          ];
        };
      };

      alertmanagers = [
        {
          static_configs = [{targets = ["127.0.0.1:${toString ports.alertmanager}"];}];
        }
      ];

      scrapeConfigs = [
        {
          job_name = "alertmanager";
          static_configs = [
            {
              targets = ["127.0.0.1:${toString ports.alertmanager}"];
            }
          ];
        }
      ];
    };

    environment.persistence."/persist".directories = ["/var/lib/private/alertmanager"];
  };
}
