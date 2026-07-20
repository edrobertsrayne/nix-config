_: {
  flake.settings.ports = {
    # Infrastructure
    ssh = 22;
    http = 80;
    https = 443;
    dns = 53;
    unbound = 5335;

    # Monitoring
    prometheus = 9090;
    alertmanager = 9093;
    alertmanagerNtfy = 9094;
    grafana = 3000;
    loki = 3100;
    alloy = 12345;

    # Exporters (9xxx series)
    exporters = {
      node = 9100;
      nginx = 9113;
      zfs = 9134;
      cadvisor = 9338;
      smartctl = 9633;
    };

    # Media services
    media = {
      jellyfin = 8096;
      seerr = 5055;
      radarr = 7878;
      sonarr = 8989;
      lidarr = 8686;
      bazarr = 6767;
      prowlarr = 9696;
      sabnzbd = 8080;
      transmission = 9091;
      transmissionPeer = 51413;
      flaresolverr = 8191;
      slskd = 5030;
      slskdListen = 50300;
      soularr = 8265;
      navidrome = 4533;
      minidlna = 8200;
    };

    # Applications
    blocky = 4000;
    vaultwarden = 8222;
    portainer = 9000;
    portainerHTTPS = 9443;
    portainerEdge = 8000;
    karakeep = 8081;
    mealie = 8223;
    stirlingPdf = 8082;
    n8n = 5678;
    ntfy = 2586;
    immich = 2283;
    codeServer = 8888;
    searxng = 8083;
    logseq = 8084;
    homepage = 8086;
    paperless = 28981;
    joplin = 22300;
    bentopdf = 8085;
    barAssistant = {
      server = 8087;
      meilisearch = 8088;
      saltRim = 8089;
    };
  };
}
