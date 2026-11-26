# Working in this repo

The code is the documentation. Do not add README or docs for anything the code
already shows; put a short comment next to the code only for a non-obvious
constraint (why, never what or when). Runbooks that code cannot express live in
`docs/`.

- Before SSHing (or `tailscale ssh`-ing) into thor, mimir, or njord to check
  status/logs, run `hostname` first — the session may already be running
  directly on the target machine (e.g. on thor itself), in which case just
  run the commands locally instead of over SSH.
- `import-tree` loads every git-tracked `.nix` file under `modules/`. A new
  file does nothing until it is `git add`-ed. Files prefixed `_` are tracked
  but not auto-loaded; the host's main file imports them explicitly.
- Deploy: `nix flake check`, then `sudo nixos-rebuild test --flake .#thor`
  (reverts on reboot), then `switch`. mimir and njord are microvm guests built
  and deployed by thor's rebuild; never rebuild them on the guest itself.
- thor's root is wiped every boot. State that must survive is declared in the
  owning module or `modules/persistence.nix`.
- Secrets: see the `secrets` skill.
