{inputs, ...}: let
  inherit (inputs.self.settings) ports;
  downloadDir = "/mnt/ssd/downloads/slskd/complete";
in {
  flake.modules.nixos.soularr = {
    config,
    pkgs,
    ...
  }: let
    # Real key is injected at activation time by soularr-config.service, which
    # substitutes this placeholder for the lidarr-apikey secret (shared with
    # media/lidarr.nix - not a second copy) before the container starts.
    configFile = pkgs.writeText "soularr-config.ini" ''
      [Lidarr]
      api_key = @LIDARR_API_KEY@
      host_url = http://host.docker.internal:${toString ports.media.lidarr}
      download_dir = ${downloadDir}
      disable_sync = False

      [Slskd]
      # slskd auth is disabled, so this value is ignored by slskd.
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
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Soularr";
        subdomain = "soularr";
        port = ports.media.soularr;
        group = "Media";
        description = "Lidarr <-> slskd bridge";
        icon = "soularr.png";
      })
    ];

    # writable /data for lock + log files, owned to match container user 306:992
    systemd.tmpfiles.rules = ["d /srv/soularr 0775 306 992 -"];

    # slskd's web port isn't otherwise firewall-opened (only its soulseek
    # listen port is); soularr reaches it via host.docker.internal, which
    # arrives as non-loopback traffic on docker0 and needs an explicit allow.
    networking.firewall.interfaces.docker0.allowedTCPPorts = [ports.media.slskd];

    # reuse of lidarr's own secret - see media/lidarr.nix's age.secrets.lidarr-apikey.
    # (security#185: old plaintext *arr keys are rotated dead by this change;
    # no git-history rewrite done - it'd break every clone/CI ref for no
    # remaining benefit once the keys themselves are inert.)
    age.secrets.lidarr-apikey.file = ../../secrets/lidarr-apikey.age;

    # configFile bakes in a placeholder api_key (not a real secret, so it's
    # fine in the Nix store); this renders the real config.ini into
    # /srv/soularr, which is already bind-mounted to /data in the container,
    # so no separate ro mount for it is needed.
    systemd.services.soularr-config = {
      before = ["docker-soularr.service"];
      requiredBy = ["docker-soularr.service"];
      serviceConfig.Type = "oneshot";
      script = ''
        apikey=$(${pkgs.gnused}/bin/sed -n 's/^LIDARR__AUTH__APIKEY=//p' ${config.age.secrets.lidarr-apikey.path})
        ${pkgs.gnused}/bin/sed "s/@LIDARR_API_KEY@/$apikey/" ${configFile} > /srv/soularr/config.ini
        ${pkgs.coreutils}/bin/chown 306:992 /srv/soularr/config.ini
        ${pkgs.coreutils}/bin/chmod 0640 /srv/soularr/config.ini
      '';
    };

    virtualisation.oci-containers.containers.soularr = {
      image = "mrusse08/soularr:latest";
      autoStart = true;
      user = "306:992"; # lidarr uid : tank gid - aligns import perms
      environment = {
        TZ = "Etc/UTC";
        SCRIPT_INTERVAL = "900"; # 15 min
        WEBUI_ENABLED = "true";
      };
      ports = ["127.0.0.1:${toString ports.media.soularr}:8265"];
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
}
