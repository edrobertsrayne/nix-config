let
  thor = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfbR2f2V1ytWjQUKe1qOddc4JXqQj611nBnPGSmZHFR";
  mimir = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILFb46rrCo5FrLieo8SE9ALd7PfTXMqBCjPdcvcx3nqr";
  systems = [thor];
  mimirSystems = [thor mimir];
  users = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINW5tgMzPytrfk373U9EfL5ol6No9lIelF6dL8ZYSe0B ed@thor"
  ];
in {
  "tailscale.age".publicKeys = mimirSystems ++ users;
  "homepage.age".publicKeys = systems ++ users;
  "cloudflare-thor.age".publicKeys = systems ++ users;
  "cloudflare-dns.age".publicKeys = systems ++ users;
  "karakeep.age".publicKeys = systems ++ users;
  "mealie.age".publicKeys = systems ++ users;
  "n8n.age".publicKeys = systems ++ users;
  "searxng.age".publicKeys = systems ++ users;
  "grafana.age".publicKeys = systems ++ users;
  "ntfy-alert-topics.age".publicKeys = systems ++ users;
  "bar-assistant.age".publicKeys = systems ++ users;
  "slskd.age".publicKeys = mimirSystems ++ users;
  "code-server.age".publicKeys = systems ++ users;
  "radarr-apikey.age".publicKeys = mimirSystems ++ users;
  "sonarr-apikey.age".publicKeys = mimirSystems ++ users;
  "lidarr-apikey.age".publicKeys = mimirSystems ++ users;
  "prowlarr-apikey.age".publicKeys = mimirSystems ++ users;
  "sabnzbd.age".publicKeys = mimirSystems ++ users;
  "user-password.age".publicKeys = systems ++ users;
  "root-password.age".publicKeys = systems ++ users;
}
