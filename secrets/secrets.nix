let
  thor = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfbR2f2V1ytWjQUKe1qOddc4JXqQj611nBnPGSmZHFR";
  systems = [thor];
  users = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINW5tgMzPytrfk373U9EfL5ol6No9lIelF6dL8ZYSe0B ed@thor"
  ];
in {
  "tailscale.age".publicKeys = systems ++ users;
  "homepage.age".publicKeys = systems ++ users;
  "kavita.age".publicKeys = systems ++ users;
  "cloudflare-thor.age".publicKeys = systems ++ users;
  "karakeep.age".publicKeys = systems ++ users;
  "mealie.age".publicKeys = systems ++ users;
  "n8n.age".publicKeys = systems ++ users;
  "searxng.age".publicKeys = systems ++ users;
  "grafana.age".publicKeys = systems ++ users;
  "paperless.age".publicKeys = systems ++ users;
}
