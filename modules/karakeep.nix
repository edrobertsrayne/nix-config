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
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Karakeep";
        subdomain = "keep";
        inherit port;
        group = "Productivity";
        description = "Bookmark manager";
        icon = "karakeep.png";
        probePath = "/api/health";
      })
    ];

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
      meilisearch.settings.upgrade_db = true;
    };

    # nixpkgs' karakeep module unconditionally sets
    # services.meilisearch.settings.experimental_dumpless_upgrade, a field meilisearch
    # 1.51 renamed to upgrade_db — the generated config.toml no longer parses.
    # Not fixed upstream as of nixpkgs master. Drop once it is. See issue #190.
    #
    # This must run *after* the meilisearch module installs config.toml into
    # $RUNTIME_DIRECTORY. It used to be `preStart = lib.mkAfter ...`, which worked
    # while upstream also installed the config from preStart; upstream moved that
    # install to serviceConfig.ExecStartPre, and NixOS renders preStart as the
    # *first* ExecStartPre entry, so the strip ran before the file existed.
    # Appending to ExecStartPre with mkAfter pins the ordering either way.
    #
    # `sed -i` calls fchown(), blocked by this unit's SystemCallFilter
    # (~@privileged @resources) -> SIGSYS. Use grep+mv (rename only) instead.
    systemd.services.meilisearch.serviceConfig.ExecStartPre = lib.mkAfter [
      (pkgs.writeShellScript "meilisearch-strip-dumpless-upgrade" ''
        set -e
        ${lib.getExe pkgs.gnugrep} -v '^experimental_dumpless_upgrade' \
          "$RUNTIME_DIRECTORY/config.toml" > "$RUNTIME_DIRECTORY/config.toml.new"
        mv "$RUNTIME_DIRECTORY/config.toml.new" "$RUNTIME_DIRECTORY/config.toml"
      '')
    ];

    fonts = {
      fontconfig.enable = lib.mkForce true;
      packages = [pkgs.noto-fonts];
    };

    environment.persistence."/persist".directories = [
      "/var/lib/karakeep"
      "/var/lib/private/karakeep-browser"
      "/var/lib/private/meilisearch"
    ];
  };
}
