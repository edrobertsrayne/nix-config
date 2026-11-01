{inputs, ...}: let
  dir = inputs.self.lib.textfileDir;
in {
  # node-exporter reads every *.prom in here. It takes a single
  # --collector.textfile.directory, so every module that publishes textfile
  # metrics shares this one directory and imports this aspect instead of
  # setting the flag itself.
  flake.lib.textfileDir = "/var/lib/prometheus-node-exporter-textfile";

  flake.modules.nixos.textfile-collector = {
    # Imported by docker-health and restic, possibly on the same host. Without
    # a key each import appends the flag again, and node-exporter refuses a
    # repeated flag.
    key = "textfile-collector-aspect";

    services.prometheus.exporters.node = {
      enabledCollectors = ["textfile"];
      extraFlags = ["--collector.textfile.directory=${dir}"];
    };

    # World-readable: node-exporter runs as its own user and only reads.
    systemd.tmpfiles.rules = ["d ${dir} 0755 root root -"];
  };
}
