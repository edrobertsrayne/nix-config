{inputs, ...}: let
  inherit (inputs.self.settings) ports;
  downloadDir = "/mnt/ssd/downloads/slskd/complete";
in {
  flake.modules.nixos.soularr = {
    config,
    pkgs,
    ...
  }: let
    # oci-containers names its systemd unit after the backend (docker-soularr
    # vs podman-soularr); thor uses docker, mimir uses podman.
    containerUnit = "${config.virtualisation.oci-containers.backend}-soularr.service";

    configFile = pkgs.writeText "soularr-config.ini" ''
      [Lidarr]
      api_key = @LIDARR_API_KEY@
      host_url = http://host.docker.internal:${toString ports.media.lidarr}
      download_dir = ${downloadDir}
      disable_sync = False

      [Slskd]
      # slskd has authentication disabled, so slskd ignores this value.
      api_key = disabled
      host_url = http://host.docker.internal:${toString ports.media.slskd}
      url_base = /
      download_dir = ${downloadDir}
      delete_searches = False
      stalled_timeout = 3600
      remote_queue_timeout = 300

      [Release Settings]
      use_selected_lidarr_release = False
      use_most_common_tracknum = True
      allow_multi_disc = True
      accepted_countries = Europe,Japan,United Kingdom,United States,[Worldwide],Australia,Canada
      skip_region_check = False
      accepted_formats = CD,Digital Media,Vinyl

      [Search Settings]
      search_timeout = 5000
      maximum_peer_queue = 50
      minimum_peer_upload_speed = 0
      minimum_filename_match_ratio = 0.8
      minimum_search_interval = 5
      allowed_filetypes = flac 24/192,flac 16/44.1,flac,mp3 320,mp3
      album_prepend_artist = False
      search_type = incrementing_page
      number_of_albums_to_grab = 10
      search_source = missing
      failed_import_denylist = True

      [Download Settings]
      download_filtering = True
      use_extension_whitelist = False
      extensions_whitelist = lrc,nfo,txt

      [Logging]
      level = INFO
      format = [%(levelname)s|%(module)s|L%(lineno)d] %(asctime)s: %(message)s
      datefmt = %Y-%m-%dT%H:%M:%S%z
      log_to_file = True
      log_file = soularr.log
      max_bytes = 1048576
      backup_count = 3
    '';
  in {
    systemd.tmpfiles.rules = ["d /srv/soularr 0775 306 992 -"];

    # The container reaches lidarr/slskd via host.docker.internal (= the
    # podman bridge gateway, 10.88.0.1), which arrives as INPUT traffic on
    # the bridge interface. Scoped to the interface rather than opening the
    # ports LAN-wide. docker0 covers a docker backend; podman0 covers the
    # podman backend mimir actually uses — without it, nixos-fw drops the
    # container's API calls (observed as PyarrConnectionError timeouts in
    # soularr's log on every boot).
    networking.firewall.interfaces.docker0.allowedTCPPorts = [ports.media.slskd ports.media.lidarr];
    networking.firewall.interfaces.podman0.allowedTCPPorts = [ports.media.slskd ports.media.lidarr];

    age.secrets.lidarr-apikey.file = ../../secrets/lidarr-apikey.age;

    systemd.services.soularr-config = {
      before = [containerUnit];
      requiredBy = [containerUnit];
      serviceConfig.Type = "oneshot";
      script = ''
        apikey=$(${pkgs.gnused}/bin/sed -n 's/^LIDARR__AUTH__APIKEY=//p' ${config.age.secrets.lidarr-apikey.path})
        ${pkgs.gnused}/bin/sed "s/@LIDARR_API_KEY@/$apikey/" ${configFile} > /srv/soularr/config.ini
        ${pkgs.coreutils}/bin/chown 306:992 /srv/soularr/config.ini
        ${pkgs.coreutils}/bin/chmod 0640 /srv/soularr/config.ini
      '';
    };

    virtualisation.oci-containers.containers.soularr = {
      # Fully qualified so podman (mimir's backend) doesn't need
      # unqualified-search registries configured to resolve it.
      image = "docker.io/mrusse08/soularr:latest";
      autoStart = true;
      user = "306:992"; # lidarr uid : tank gid - aligns import perms
      environment = {
        TZ = "Etc/UTC";
        SCRIPT_INTERVAL = "900"; # 15 min
        WEBUI_ENABLED = "true";
      };
      # podman's port publishing DNATs by destination IP and bypasses
      # networking.firewall entirely, so (unlike every other service here,
      # which relies on the firewall) the bind address itself is the access
      # control. Bound to both: mimir's LAN address, and mimir's tailnet
      # address because nginx's proxyPass now reaches mimir over tailscale0.
      ports = [
        "${inputs.self.settings.hosts.mimir.address}:${toString ports.media.soularr}:8265"
        "${inputs.self.settings.hosts.mimir.tailnetAddress}:${toString ports.media.soularr}:8265"
      ];
      volumes = [
        "/srv/soularr:/data"
        "${downloadDir}:${downloadDir}" # same path in-container so both agree
      ];
      extraOptions = [
        "--pull=always"
        "--add-host=host.docker.internal:host-gateway"
      ];
    };
  };

  # See docs/deploying.md, "Same-host vs. cross-host services", for why this module exists.
  flake.modules.nixos.soularr-proxy = inputs.self.lib.mkProxiedService {
    name = "Soularr";
    subdomain = "soularr";
    port = ports.media.soularr;
    group = "Media";
    description = "Lidarr <-> slskd bridge";
    icon = "soularr.png";
    # This module sets no probePath. soularr exposes no health endpoint.
    host = inputs.self.settings.hosts.mimir.tailnetName;
  };
}
