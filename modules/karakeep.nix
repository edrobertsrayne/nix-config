{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
in {
  flake.modules.nixos.karakeep = {
    config,
    lib,
    pkgs,
    ...
  }: let
    url = "keep.${server.domain}";
    port = ports.karakeep;
  in {
    nixpkgs.config.permittedInsecurePackages = ["pnpm-9.15.9"];
    age.secrets.karakeep.file = ../secrets/karakeep.age;
    services = {
      karakeep = {
        enable = true;
        extraEnvironment = {
          PORT = "${toString port}";
          NEXTAUTH_URL = "https://${url}";
        };
        environmentFile = config.age.secrets.karakeep.path;
      };
      nginx.virtualHosts."${url}" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString port}";
          proxyWebsockets = true;
        };
      };
      meilisearch.settings.upgrade_db = true;
    };

    # nixpkgs' karakeep module unconditionally sets
    # services.meilisearch.settings.experimental_dumpless_upgrade, a field meilisearch
    # 1.51 renamed to upgrade_db — the generated config.toml no longer parses.
    # Not fixed upstream as of nixpkgs master. Drop once it is. See issue #190.
    # `sed -i` calls fchown(), blocked by this unit's SystemCallFilter
    # (~@privileged @resources) -> SIGSYS. Use grep+mv (rename only) instead.
    systemd.services.meilisearch.preStart = lib.mkAfter ''
      ${lib.getExe pkgs.gnugrep} -v '^experimental_dumpless_upgrade' "$RUNTIME_DIRECTORY/config.toml" > "$RUNTIME_DIRECTORY/config.toml.new"
      mv "$RUNTIME_DIRECTORY/config.toml.new" "$RUNTIME_DIRECTORY/config.toml"
    '';

    fonts = {
      fontconfig.enable = lib.mkForce true;
      packages = [pkgs.noto-fonts];
    };

    homepage.services."Productivity" = [
      {
        Karakeep = {
          href = "https://${url}";
          description = "Bookmark manager";
          icon = "karakeep.png";
          siteMonitor = "http://127.0.0.1:${toString port}";
        };
      }
    ];
  };
}
