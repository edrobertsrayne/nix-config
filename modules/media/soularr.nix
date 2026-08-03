{inputs, ...}: let
  inherit (inputs.self.settings) ports;
  downloadDir = "/mnt/ssd/downloads/slskd/complete";
  lidarrApiKey = "f6a4315040e94c7c9eb2aefe5bfc4445"; # must match media/lidarr.nix
in {
  flake.modules.nixos.soularr = {pkgs, ...}: let
    # slskd auth is disabled, so this value is ignored by slskd; kept valid-length.
    slskdApiKey = "soularr0000000000000000000000000";
    configFile = pkgs.writeText "soularr-config.ini" ''
      [Lidarr]
      api_key = ${lidarrApiKey}
      host_url = http://host.docker.internal:${toString ports.media.lidarr}
      download_dir = ${downloadDir}
      disable_sync = False

      [Slskd]
      api_key = ${slskdApiKey}
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
        "${configFile}:/data/config.ini:ro"
        "${downloadDir}:${downloadDir}" # same path in-container so both agree
      ];
      extraOptions = [
        "--pull=always"
        "--add-host=host.docker.internal:host-gateway"
      ];
    };
  };
}
