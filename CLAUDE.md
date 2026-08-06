# NixOS Config — Agent Rules

Dendritic NixOS config, single host (`thor`), aspect-oriented. `import-tree`
auto-loads every git-tracked `.nix` file under `modules/`.

## Core Rules

1. `git add` new `.nix` files immediately — untracked files aren't loaded, so
   an untracked file plus its auto-generated option collide as "option defined
   multiple times".
2. Run Quality Checks before committing.
3. Multi-commit work: edit → check → commit, one logical change at a time.
   Never batch edits then split into commits after.
4. Be concise — brevity over grammar, in chat and commits.
5. Use Context7 for flake-input docs (nvf, agenix, home-manager, disko,
   flake-parts, import-tree) — don't rely on trained knowledge.
6. Planning issue-tracked work ends by writing the plan into the issue
   (`gh issue edit --body-file`), not by executing it. Propagate findings to
   parent/downstream issues too. Only edit `.nix` files once asked to implement.

## Applying Changes

Bash runs directly on thor — no SSH hop needed.

`sudo nixos-rebuild test --flake .#thor`. **Never `switch`** — `test` doesn't
touch the boot default, so a reboot recovers the box; `switch` removes that
escape hatch on a host running household services. `nix flake check` is the
pre-commit gate.

This binds agent commands only, not the repo's docs — README and
`docs/deploying.md` present `test`/`switch`/`boot` neutrally.

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

Name files by aspect/purpose (`ssh.nix`), not by host.

Docs: lowercase-kebab, live in `docs/` only — never beside the module, never
SHOUTING_CASE. `modules/` holds Nix and data only. Moving a doc: `git mv` it
and repoint every inbound link (README, host READMEs, doc-to-doc, Nix
comments).

`_name.nix` — tracked but excluded from import-tree; parent must
`imports = [ ./_name.nix ];` explicitly. Use for host-specific or
side-effecting config that must not auto-load elsewhere.

## Aspect Conventions

Each file contributes **one** `flake.modules.nixos.<aspect>` block. All
cross-aspect wiring (Prometheus scrape job, Grafana datasource, nginx vhost,
homepage entry, postgres user) goes inside that block, not a second block or
the exporter's own file. Exception: a file whose only purpose is that aspect
(`modules/alert-rules.nix`).

- Options that no-op when disabled (`scrapeConfigs`, Grafana `datasources`):
  set unconditionally.
- Options that would strand a resource (`postgresql.ensureUsers`): gate on
  `config.services.<other>.enable`.

An aspect imported by more than one other aspect (e.g. `postgresql.nix`,
`intel-vaapi.nix`) needs an explicit `key` — otherwise the module system
treats each import as distinct and concatenates list options across
importers, tripping impermanence's `duplicateDirs` assertion for any aspect
that also declares a persistence path.

`services.prometheus.scrapeConfigs` and
`services.grafana.provision.datasources.settings.{datasources,deleteDatasources}`
are plain `listOf []`, so definitions from many aspects concatenate safely.
Check for `nullOr` before assuming this of a new option — it throws if one
definition is null and another isn't.

## Persistence (impermanence)

- `nixos-rebuild test` starts new `systemd.mounts` immediately, so
  `environment.persistence."/persist"` bind mounts go live under running
  services. Use `boot` + reboot instead when adding/changing a persisted path.
- impermanence chmods parent dirs to match `/persist`. `/var/lib/private`
  needs `0700 root:root` or `DynamicUser` services fail to start — pinned in
  `modules/persistence.nix`.

## Settled Decisions — Don't Re-Litigate

- **Cloudflare Access (Google auth)** is the auth layer for `*.greensroad.uk`.
  No basicAuth, oauth2-proxy, `auth_request`, per-app logins, or
  exposure-policy docs. Real bugs here are LAN bypasses — `openFirewall`, or
  Docker port publishes skipping the firewall via `DOCKER-USER`.
- **Container images are unpinned on purpose** — `:latest` + `--pull=always`
  everywhere. Don't pin tags/digests, don't "fix" this in a hardening review.
- **Bind address follows the client.** No split-horizon DNS, so
  `*.greensroad.uk` resolves to Cloudflare even on the tailnet. Mobile/non-SSO
  clients → bind `0.0.0.0`, rely on the firewall (immich, navidrome).
  Admin-only browser UI → bind `127.0.0.1` (transmission, searxng, n8n).
  `openFirewall` is never the answer. See `docs/networking.md`.
- **Drop the setting, don't override upstream.** When a nixpkgs module fights
  the config, stop setting the option rather than `mkForce`-ing its output
  back into shape.

## Quality Checks

```bash
nix flake check   # evaluates thor; failure is usually a missing `git add`
```

Formatting/lint (alejandra, statix, deadnix) run automatically via devenv git
hooks, a PostToolUse hook, and CI. Don't invoke by hand.

## Commit Format

Conventional Commits, aspect as scope: `<type>(<aspect>): <description>`.
Types: `feat`, `fix`, `refactor`, `style`, `docs`, `chore`.

One commit per logical change; refactor before feature.

- `feat(neovim): add LSP support for Rust`
- `fix(blocky): correct upstream resolver timeout`

## Anti-Patterns

- Host-centric organization → use aspect modules.
- Package-centric modules → group by purpose.
- Manual import management → trust import-tree.
- Interdependent feature modules → use aggregators or custom options.

## Maintaining This File

Operational only: rules, paths, commands, formats. No overview, no prose, no
links. Rationale allowed as a short inline clause when it prevents a concrete
failure.

**Write down what cost you time — but only if it is _generally applicable_.**
This file holds rules that bind every aspect: repo conventions, module-system
behavior, deploy commands, formats. A wrong option name, a non-obvious eval
failure, a surprising merge behavior, an undocumented required step — add the
resolved fact here, same commit as the fix. Add the answer, not the story.

Two tests, both must pass:

1. Would a fresh agent repeat the detour?
2. Does it apply beyond the one service that surfaced it?

A finding that fails test 2 is **service-specific** and does not belong here —
upstream defaults, a package's env vars, one module's quirks. Put it where the
reader already is:

| Finding                                     | Goes                       |
| ------------------------------------------- | -------------------------- |
| Why this module sets a surprising value      | Comment beside the setting |
| How a service is wired, operational caveats  | `docs/{name}.md`           |
| Binds every aspect                           | Here                       |

Growing this file with per-service trivia makes the rules that _do_ bind
everything harder to find.

**This repo is the single source of truth.** Learnings, decisions, and
corrections go here or in `docs/` — never only in a local Claude instance's
memory. Memory is fine for this assistant's own tooling/behavior; anything
about the project must live in the repo so any agent or human can read it.
