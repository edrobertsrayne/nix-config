{lib, ...}: {
  options.flake.settings.mimir = with lib; {
    # thor resolves Tailscale MagicDNS hostnames (confirmed live:
    # `tailscale debug prefs | grep CorpDNS` is true, `getent hosts <peer>`
    # resolves other tailnet devices - see the accept-dns correction on
    # #203), so nginx can proxy to mimir by name instead of a hardcoded IP.
    # No placeholder needed: `mimir` (networking.hostName,
    # modules/hosts/mimir/mimir.nix) will resolve as soon as it registers on
    # the tailnet, same as `thor` does today.
    tailscaleHost = mkOption {
      type = types.str;
      default = "mimir";
    };
  };
}
