# NixOS Config — Agent Rules

Dendritic NixOS config, aspect-oriented. `import-tree` auto-loads every
git-tracked `.nix` file under `modules/`.

## Core Rules

1. **`git add` new `.nix` files immediately** — import-tree only loads tracked
   files; an untracked file plus its auto-generated option collide as "option
   defined multiple times".
2. Run all checks (below) before committing; confirm with user before the commit
   itself.
3. Multi-commit work: commit each logical change (edit, check, commit) before
   editing for the next. Never batch edits across commits then split after.
4. Be concise — sacrifice grammar for brevity, in chat and commits.
5. Use Context7 proactively for flake-input docs (nvf, agenix, home-manager,
   disko, flake-parts, import-tree) — don't rely on trained knowledge.

## Module Placement

| Type             | Location                      | Example                            |
| ---------------- | ----------------------------- | ---------------------------------- |
| Simple aspect    | `modules/{name}.nix`          | `modules/ssh.nix`                  |
| Complex feature  | `modules/{feature}/`          | `modules/neovim/lsp.nix`           |
| Host-specific    | `modules/hosts/{hostname}/`   | `modules/hosts/thor/_hardware.nix` |
| Project option   | `modules/settings/{name}.nix` | `modules/settings/ports.nix`       |
| Helper functions | `modules/lib/{name}.nix`      | `modules/lib/hosts.nix`            |

Name files by aspect/purpose (`ssh.nix`, `development-tools.nix`), not host.

## Underscore Prefix

`_name.nix` — tracked but excluded from import-tree auto-load; parent module
must `imports = [ ./_name.nix ];` explicitly. Use for host-specific or
side-effecting (opens ports, enables services) config that must not auto-load
elsewhere.

## Aspect Conventions

- Keep an aspect's full config in one `flake.modules.nixos.<aspect>` block —
  don't split one aspect across files.
- Gate cross-aspect wiring on `config.services.<X>.enable`, not on import order.

## Quality Checks

Run before every commit:

```bash
nix flake check --impure   # build; fix: usually a missing `git add`
```

(Also enforced as devenv git hooks — see `devenv.nix`.)

## Commit Format

Conventional Commits, aspect name as scope: `<type>(<aspect>): <description>`

Types: `feat`, `fix`, `refactor`, `style`, `docs`, `chore`.

One commit per logical change. Split refactor from new feature (refactor first).
Examples:

- `feat(neovim): add LSP support for Rust`
- `fix(hyprland): correct keybind for workspace switching`
- `refactor(desktop): reorganize aggregator imports`

## Anti-Patterns

- Host-centric organization → use aspect modules.
- Package-centric modules → group by purpose; only create modules that carry
  configuration.
- Manual import management → trust import-tree.
- Interdependent feature modules → use aggregators or custom options.
