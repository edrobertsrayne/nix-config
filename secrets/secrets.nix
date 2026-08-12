let
  thor = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfbR2f2V1ytWjQUKe1qOddc4JXqQj611nBnPGSmZHFR";
  # mimir (#203): not added to `systems` yet. Its SSH host key only exists
  # once it's actually provisioned - a placeholder key here would silently
  # produce secrets no real host can decrypt. Once mimir has booted once:
  # add its ssh-ed25519 host public key to `systems` below, then `agenix -r`
  # to rekey every secret (matches this repo's "every machine decrypts every
  # secret" policy - see #203 decision log).
  systems = [thor];
  users = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINW5tgMzPytrfk373U9EfL5ol6No9lIelF6dL8ZYSe0B ed@thor"
  ];
in {
  "tailscale.age".publicKeys = systems ++ users;
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
  "slskd.age".publicKeys = systems ++ users;
  "code-server.age".publicKeys = systems ++ users;
  "radarr-apikey.age".publicKeys = systems ++ users;
  "sonarr-apikey.age".publicKeys = systems ++ users;
  "lidarr-apikey.age".publicKeys = systems ++ users;
  "prowlarr-apikey.age".publicKeys = systems ++ users;
  "sabnzbd.age".publicKeys = systems ++ users;
  "user-password.age".publicKeys = systems ++ users;
  "root-password.age".publicKeys = systems ++ users;
}
