# NixOS Config — Agent Rules

Dendritic NixOS config, single host (`thor`), aspect-oriented. `import-tree`
auto-loads every git-tracked `.nix` file under `modules/`.

## Core Rules

1. **`git add` new `.nix` files immediately** — import-tree only loads tracked
   files; an untracked file plus its auto-generated option collide as "option
   defined multiple times".
2. Run the checks below before committing.
3. Multi-commit work: commit each logical change (edit → check → commit) before
   editing for the next. Never batch edits across commits then split after.
4. Be concise — sacrifice grammar for brevity, in chat and commits.
5. Use Context7 for flake-input docs (nvf, agenix, home-manager, disko,
   flake-parts, import-tree) — don't rely on trained knowledge.

## Applying Changes

Use `sudo nixos-rebuild test --flake .#thor`. **Never `switch`.** `test`
activates without touching the boot default, so a reboot recovers the box;
`switch` removes that escape hatch on a host running the household's services.
Use `nix flake check` as the pre-commit gate.

This constrains commands the agent runs or tells the user to run. It is not a
house rule about the repo: README and `docs/deploying.md` present `test`,
`switch` and `boot` neutrally with their real trade-offs. Keep it that way.

## Module Placement

| Type             | Location                      | Example                            |
| ---------------- | ----------------------------- | ---------------------------------- |
| Simple aspect    | `modules/{name}.nix`          | `modules/ssh.nix`                  |
| Complex feature  | `modules/{feature}/`          | `modules/neovim/lsp.nix`           |
| Host-specific    | `modules/hosts/{hostname}/`   | `modules/hosts/thor/_hardware.nix` |
| Project option   | `modules/settings/{name}.nix` | `modules/settings/ports.nix`       |
| Helper functions | `modules/lib/{name}.nix`      | `modules/lib/hosts.nix`            |
| Prose docs       | `docs/{name}.md`              | `docs/monitoring.md`               |
| Dashboard JSON   | `modules/dashboards/`         | `modules/dashboards/blocky.json`   |

Name files by aspect/purpose (`ssh.nix`, `development-tools.nix`), not by host.

Docs are lowercase-kebab and live in `docs/` — never beside the module they
describe, never SHOUTING_CASE. `modules/` holds Nix and data only. When a doc
moves, `git mv` it and repoint every inbound link (root README, host READMEs,
doc-to-doc links, paths named in Nix comments).

`_name.nix` — tracked but excluded from import-tree auto-load; the parent module
must `imports = [ ./_name.nix ];` explicitly. Use for host-specific or
side-effecting config that must not auto-load elsewhere.

## Aspect Conventions

Each file contributes **one** `flake.modules.nixos.<aspect>` block. All
cross-aspect wiring goes inside that block — a Prometheus scrape job, a Grafana
datasource, an nginx vhost, a homepage entry, a postgres user. Splitting a
secondary `flake.modules.nixos.prometheus = ...` block into the same file is
wrong; so is putting a scrape job in the exporter's own module file instead of
the aspect. The exception is a file whose *only* purpose is that aspect
(`modules/alert-rules.nix`).

- Options that no-op when the consumer is disabled (`scrapeConfigs`, Grafana
  `datasources`): set unconditionally.
- Options that would strand a resource (`postgresql.ensureUsers`): gate on
  `config.services.<other>.enable` via `lib.optional` / `lib.mkIf`.

Merge mechanics: `services.prometheus.scrapeConfigs` and
`services.grafana.provision.datasources.settings.{datasources,deleteDatasources}`
are plain `listOf` defaulting to `[]`, so definitions from many aspects
concatenate. Check for `nullOr` before assuming this of a new option — `nullOr`
throws when one definition is null and another isn't.

## Settled Decisions — Don't Re-Litigate

- **Cloudflare Access (Google auth) is the auth layer** for `*.greensroad.uk`.
  Don't propose basicAuth, oauth2-proxy, `auth_request`, per-app logins, or
  standalone exposure-policy docs. Real security bugs here are LAN bypasses —
  `openFirewall = true`, or Docker port publishes that skip the NixOS firewall
  via `DOCKER-USER`.
- **Container images are unpinned on purpose.** `:latest` + `--pull=always`
  repo-wide is deliberate on a personal server already tracking nixpkgs
  unstable. Don't pin tags or digests, and don't "fix" it when a hardening
  review flags it.
- **Bind address follows the client, not habit.** No split-horizon DNS exists,
  so `*.greensroad.uk` resolves to Cloudflare even on the tailnet. A service
  with a mobile/non-browser client that can't do Google SSO binds `0.0.0.0` and
  relies on the firewall as the boundary (immich, navidrome); an admin-only
  browser UI binds `127.0.0.1` (transmission, searxng, n8n). `openFirewall` is
  not the answer either way. See `docs/networking.md`.
- **Drop the setting rather than override upstream.** When a nixpkgs module
  fights the config, stop setting the option and take its default instead of
  `mkForce`-ing its tmpfiles/systemd output back into shape. A one-off data
  migration beats an override that must track upstream forever.

## Quality Checks

```bash
nix flake check   # evaluates thor; failure is usually a missing `git add`
```

Formatting and lint (alejandra, statix, deadnix) run automatically — devenv git
hooks, a PostToolUse hook in `.claude/hooks/nix-lint.sh`, and CI. Don't invoke
them by hand.

## Commit Format

Conventional Commits, aspect name as scope: `<type>(<aspect>): <description>`.
Types: `feat`, `fix`, `refactor`, `style`, `docs`, `chore`.

One commit per logical change; split refactor from feature, refactor first.

- `feat(neovim): add LSP support for Rust`
- `fix(blocky): correct upstream resolver timeout`

## Anti-Patterns

- Host-centric organization → use aspect modules.
- Package-centric modules → group by purpose; only create a module that carries
  configuration.
- Manual import management → trust import-tree.
- Interdependent feature modules → use aggregators or custom options.

## Maintaining This File

Operational content only: rules, paths, commands, formats — things acted on.
No project overview, no background prose, no further-reading links, no
restating a rule that already appears above. Descriptive material belongs in
`README.md` or `docs/`. Rationale is allowed as a short inline clause where it
prevents a concrete failure, never as its own section.

**Write down what cost you time.** If working something out took several
attempts — a wrong option name, a non-obvious eval failure, a merge behaviour
that surprised you, a service that needed an undocumented step — add the
resolved fact here in the same commit as the fix. The test is whether a fresh
agent with no memory of this session would repeat the detour. Add the answer,
not the story of finding it.
