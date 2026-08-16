{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
in {
  flake.modules.nixos.sabnzbd = {config, ...}: let
    cfg = config.services.sabnzbd;
    url = "sabnzbd.${server.domain}";
  in {
    # owner is required: the nixpkgs module's preStart (which merges this
    # secret into sabnzbd.ini) runs as User=sabnzbd, not root.
    age.secrets.sabnzbd = {
      file = ../../secrets/sabnzbd.age;
      owner = "sabnzbd";
      group = "sabnzbd";
    };

    services = {
      sabnzbd = {
        enable = true;
        # No openFirewall: reached via cloudflared -> nginx (Access-gated) or
        # the tailnet; the LAN bridge must not reach it directly.
        configFile = null;
        secretFiles = [config.age.secrets.sabnzbd.path];
        allowConfigWrite = false;
        settings = {
          misc = {
            host_whitelist = "localhost, 127.0.0.1, ${url}, ${inputs.self.settings.hosts.thor.address}";
            local_ranges = "127.0.0.1, ::1";
            inet_exposure = "api+web (auth needed)";
            download_dir = "/mnt/ssd/downloads/usenet/incomplete";
            complete_dir = "/mnt/ssd/downloads/usenet/complete";
            permissions = "775";
            port = ports.media.sabnzbd;
            direct_unpack = true;
            direct_unpack_tested = true;
            config_lock = true;
            config_conversion_version = 5;
          };
          servers = {
            "eunews.frugalusenet.com" = {
              name = "eunews.frugalusenet.com";
              displayname = "eunews.frugalusenet.com";
              host = "eunews.frugalusenet.com";
              expire_date = "";
              connections = 75;
            };
            "news.frugalusenet.com" = {
              name = "news.frugalusenet.com";
              displayname = "news.frugalusenet.com";
              host = "news.frugalusenet.com";
              expire_date = "";
              connections = 75;
              priority = 5;
            };
            "bonus.frugalusenet.com" = {
              name = "bonus.frugalusenet.com";
              displayname = "bonus.frugalusenet.com";
              host = "bonus.frugalusenet.com";
              expire_date = "";
              connections = 40;
              priority = 10;
            };
            "eunews.blocknews.net" = {
              name = "eunews.blocknews.net";
              displayname = "eunews.blocknews.net";
              host = "eunews.blocknews.net";
              connections = 40;
              priority = 20;
              pipelining_requests = 2;
              expire_date = "";
            };
            "usnews.blocknews.net" = {
              name = "usnews.blocknews.net";
              displayname = "usnews.blocknews.net";
              host = "usnews.blocknews.net";
              connections = 40;
              priority = 30;
              pipelining_requests = 2;
              expire_date = "";
            };
          };
          categories = {
            "*" = {
              name = "*";
              order = 0;
              pp = 3;
              script = "Default";
              dir = "";
              newzbin = "";
              priority = 0;
            };
            movies = {
              name = "movies";
              order = 1;
              pp = "";
              script = "Default";
              dir = "";
              newzbin = "";
              priority = -100;
            };
            tv = {
              name = "tv";
              order = 2;
              pp = "";
              script = "Default";
              dir = "";
              newzbin = "";
              priority = -100;
            };
            audio = {
              name = "audio";
              order = 3;
              pp = "";
              script = "Default";
              dir = "";
              newzbin = "";
              priority = -100;
            };
            software = {
              name = "software";
              order = 4;
              pp = "";
              script = "Default";
              dir = "";
              newzbin = "";
              priority = -100;
            };
            prowlarr = {
              name = "prowlarr";
              order = 5;
              pp = "";
              script = "Default";
              dir = "";
              newzbin = "";
              priority = -100;
            };
            music = {
              name = "music";
              order = 6;
              pp = "";
              script = "Default";
              dir = "";
              newzbin = "";
              priority = -100;
            };
          };
        };
      };
    };

    users.users.${cfg.user}.extraGroups = ["tank"];

    systemd.tmpfiles.rules = [
      "d /mnt/ssd/downloads/usenet/complete 0755 ${cfg.user} tank -"
      "d /mnt/ssd/downloads/usenet/incomplete 0755 ${cfg.user} tank -"
    ];

    environment.persistence."/persist".directories = ["/var/lib/sabnzbd"];
  };

  # See docs/deploying.md, "Same-host vs. cross-host services", for why this module exists.
  flake.modules.nixos.sabnzbd-proxy = inputs.self.lib.mkProxiedService {
    name = "SABnzbd";
    subdomain = "sabnzbd";
    port = ports.media.sabnzbd;
    group = "Media";
    description = "Usenet downloader";
    icon = "sabnzbd.png";
    # mode=version is the one API call SABnzbd exempts from the api key.
    probePath = "/api?mode=version";
    extraConfig = ''
      proxy_set_header X-Forwarded-Host $host;
    '';
    host = inputs.self.settings.hosts.mimir.address;
  };
}
