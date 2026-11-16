{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.alertmanager-ntfy = _: {
    services.prometheus.alertmanager-ntfy = {
      enable = true;
      settings = {
        http.addr = "127.0.0.1:${toString ports.alertmanagerNtfy}";
        ntfy = {
          # Loopback, not the public vhost: that path needs DNS, nginx and
          # the ACME certificate, which are things these alerts report on.
          baseurl = "http://127.0.0.1:${toString ports.ntfy}";
          notification = {
            topic = "thor";
            priority = ''
              labels["severity"] == "critical" ? "urgent" : "high"
            '';
            tags = [
              {
                tag = "rotating_light";
                condition = ''status == "firing" && labels["severity"] == "critical"'';
              }
              {
                tag = "warning";
                condition = ''status == "firing" && labels["severity"] == "warning"'';
              }
              {
                tag = "white_check_mark";
                condition = ''status == "resolved"'';
              }
            ];
            templates = {
              title = ''
                {{ if eq .Status "resolved" }}[Resolved] {{ end }}{{ index .Labels "alertname" }}{{ if index .Labels "instance" }} on {{ index .Labels "instance" }}{{ end }}
              '';
              description = ''
                {{ with index .Annotations "summary" }}{{ . }}{{ end }}{{ with index .Annotations "description" }}
                {{ . }}{{ end }}
              '';
            };
          };
        };
      };
    };
  };
}
