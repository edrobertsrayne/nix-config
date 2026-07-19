---
name: secrets
description: Manage agenix secrets in this repo (thor host). Use when adding, editing, decrypting, or re-keying a secret, or wiring a secret into a service module. Triggers on "add secret", "create secret", "encrypt", "re-key", or a service needing credentials/API keys/env vars.
---

# Secrets (agenix)

Single-host setup: recipients in `secrets/secrets.nix` are the `thor` host
key and the `ed@thor` user key (`systems ++ users`). Encrypted blobs live
next to it as `secrets/*.age`.

## `agenix` is not on PATH here

Don't run bare `agenix`. Use:

```bash
nix run github:ryantm/agenix -- <args>
```

## Critical: run from `secrets/`

The `RULES` env var (which recipients to encrypt for) defaults to
`./secrets.nix` relative to **cwd**, not to the file path you pass. Always
`cd secrets` first and pass a bare filename (`myservice.age`), not
`secrets/myservice.age` — passing the prefixed path from repo root fails
with `attribute '"secrets/myservice.age"' missing`.

## Create a new secret

1. Register it in `secrets/secrets.nix`:
   ```nix
   "myservice.age".publicKeys = systems ++ users;
   ```
2. Encrypt, non-interactively, from `secrets/`:
   ```bash
   cd secrets
   printf 'API_KEY=%s\n' "$value" | nix run github:ryantm/agenix -- -e myservice.age
   ```
   When stdin isn't a TTY, agenix auto-sets `EDITOR=cp /dev/stdin` — no
   `$EDITOR` or heredoc juggling needed. For a truly random value with no
   `openssl` on PATH: `head -c32 /dev/urandom | xxd -p -c 256`.
3. Verify it actually decrypts before trusting it (empty/malformed pipes
   fail silently otherwise):
   ```bash
   nix run github:ryantm/agenix -- -d myservice.age
   ```
4. `git add secrets/myservice.age secrets/secrets.nix` immediately.

## Edit / view an existing secret

```bash
cd secrets
nix run github:ryantm/agenix -- -e myservice.age   # opens $EDITOR, or paste new content via stdin
nix run github:ryantm/agenix -- -d myservice.age   # decrypt to stdout
```

## Re-key (new host, rotated key, revoked access)

```bash
cd secrets
nix run github:ryantm/agenix -- -r
git add secrets/*.age secrets/secrets.nix
```

## Consuming a secret in a module

Declare once per module:
```nix
age.secrets.myservice.file = ../secrets/myservice.age;
```
From a nested host dir (e.g. `modules/hosts/thor/thor.nix`), adjust the
relative path: `../../../secrets/myservice.age` (see `thor.nix`'s
`cloudflared` secret).

Add `owner`/`group` when the service runs as a non-root user (files land in
`/run/agenix/` root-owned 0400 by default):
```nix
age.secrets.myservice = {
  file = ../secrets/myservice.age;
  owner = "myservice";
  group = "myservice";
};
```

Real consumption patterns already in this repo — match whichever the
target service's NixOS option expects, don't invent a new shape:

| Pattern | Example | Secret file format |
|---|---|---|
| `environmentFile` (singular) | `paperless.nix`, `searxng.nix` | `KEY=value` lines |
| `environmentFiles` (list) | `homepage.nix` | `KEY=value` lines |
| `credentialsFile` | `mealie.nix` | `KEY=value` lines |
| `*_FILE` env var → `.path` | `n8n.nix`: `N8N_ENCRYPTION_KEY_FILE = config.age.secrets.n8n.path` | raw value |
| `$__file{...}` interpolation | `grafana.nix`: `security.secret_key = "$__file{${config.age.secrets.grafana.path}}"` | raw value |
| OCI container `environmentFiles` | `bar-assistant.nix` | `KEY=value` lines |

For `virtualisation.oci-containers.containers.<name>`, the option is
`environmentFiles = [config.age.secrets.<name>.path];` — same idea as native
services, just under the container attrset.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `attribute '"secrets/x.age"' missing` | ran from repo root with prefixed path | `cd secrets`, use bare filename |
| decrypts to empty/garbage | a piped-in value generator failed silently (e.g. missing `openssl`) upstream of the `\|` | verify the plaintext before piping; always `-d` after `-e` to confirm |
| host can't decrypt at runtime | host key missing from that secret's `publicKeys` | add key to `secrets.nix`, `-r`, redeploy |
| `no identity found` when editing | your `~/.ssh/id_ed25519` not in `users` list | add your pubkey, get someone with access to re-key |
