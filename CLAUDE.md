# Working in this repo

- Before SSHing (or `tailscale ssh`-ing) into thor, mimir, or njord to check
  status/logs, run `hostname` first — the session may already be running
  directly on the target machine (e.g. on thor itself), in which case just
  run the commands locally instead of over SSH.
