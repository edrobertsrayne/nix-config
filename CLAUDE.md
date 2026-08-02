# NixOS Server Configuration - AI Agent Guidelines

Dendritic NixOS configuration using aspect-oriented, modular organization.
Follow workflow and rules below.

## 🔴 Critical Rules

**Override all others. Follow strictly:**

1. **Use Explore Agent**: For codebase investigation, use `Task` tool with
   `subagent_type=Explore` (not direct Grep/Glob)
2. **Use TodoWrite**: Create task list in PLAN phase, update during
   implementation
3. **Git Add Immediately**: After creating `.nix` files, run
   `git add path/to/file.nix` - import-tree only loads tracked files
   **Why:** Untracked files cause "option defined multiple times" errors:
   - Create `modules/feature.nix` defining `flake.modules.nixos.feature`
   - Forget `git add` → import-tree doesn't see it (only loads tracked files)
   - NixOS auto-generates the option
   - Conflict: auto-generated + your definition = duplicate error
4. **Wait for Approval**: Do not start CODE phase without explicit user approval
5. **All Checks Must Pass**: Do not commit until alejandra, statix, and deadnix
   pass
6. **Be Concise**: In all interactions and commits, sacrifice grammar for
   concision
7. **List Questions**: End each plan with unresolved questions (if any);
   extremely concise
8. **Use Context7 Proactively**: Automatically fetch library docs when
   implementing features using external libraries/frameworks. Don't wait for
   user request.

---

## Mandatory Workflow: Explore → Plan → Code → Commit

Follow four phases with explicit checkpoints. Do not skip.

### Phase 1: EXPLORE (Read-Only)

- Use Task tool with `subagent_type=Explore` for codebase investigation
- Read files, docs, existing implementations
- Search for similar patterns
- Ask clarifying questions

**Do not write, edit, or create files. Do not propose solutions.**

**STOP:** Present findings, ask: "Ready to move to planning phase?"

---

### Phase 2: PLAN (Design-Only)

- Check TODO.md for context; add new items as `docs(todo)` commit
- Create task list with TodoWrite (required)
- Propose implementation approach
- Identify modules needing changes
- Determine if new modules needed (see Module Placement)
- Plan testing strategy

**Do not write, edit, or create files.**

**STOP:** Present plan, list unresolved questions (if any), ask: "Does this plan
look good? Should I proceed to implementation?"

**CHECKPOINT:** Wait for explicit approval.

---

### Phase 3: CODE (Implementation)

- Follow approved plan exactly
- Create/modify files as planned
- **Immediately `git add` new `.nix` files** (critical - import-tree only loads
  tracked files)
- Update TodoWrite (one in_progress at a time)
- Test incrementally

**Do not create commits. Do not deviate from plan without asking.**

**STOP:** Run quality checks (Phase 4).

---

### Phase 4: COMMIT (Finalize)

**Run all checks (must pass):**

```bash
alejandra --check .    # Format
statix check .         # Lint
deadnix --fail .       # Dead code
nix flake check --impure  # Build (if applicable)
```

**Steps:**

1. Run checks
2. Fix issues (see Quality Requirements section)
3. Present changes summary
4. Create commit after user confirmation

**Use Conventional Commits: `<type>(<aspect>): <description>`** **Use aspect
name as scope**

**Do not commit until all checks pass and user confirms.**

**STOP:** Present results, ask: "All checks pass. Ready to commit?"

**CHECKPOINT:** Wait for explicit approval.

---

## Module Placement

| Type             | Location                       | Example                            |
| ---------------- | ------------------------------ | ---------------------------------- |
| Simple aspect    | `modules/{name}.nix`           | `modules/ssh.nix`                  |
| Complex feature  | `modules/{feature}/`           | `modules/neovim/lsp.nix`           |
| Host-specific    | `modules/hosts/{hostname}/`    | `modules/hosts/thor/hardware.nix`  |
| Project option   | `modules/settings/{name}.nix` | `modules/settings/user.nix`      |
| Helper functions | `modules/lib/{name}.nix`       | `modules/lib/hosts.nix`           |

**Naming:** Use aspect/purpose names (`ssh.nix`, `development-tools.nix`), not
host names.

---

## Underscore Prefix Pattern

**Files with `_` prefix are git-tracked but excluded from import-tree auto-loading.**

**Use when:**
- Host-specific config shouldn't auto-load on other hosts
- Module has side effects (enables services, opens ports)
- Explicit dependency declaration needed for safety

**Example:**
```nix
# modules/hosts/thor/_hardware.nix - Not auto-loaded despite being tracked
# modules/hosts/thor/thor.nix
imports = [ ./_hardware.nix ];  # Explicit import required
```

**Behavior:**
- Tracked in git (version control, collaboration)
- Excluded from automatic import-tree loading
- Require manual import in parent module
- Create "private" modules with opt-in loading

**Pattern creates visibility gradations:**
1. Public modules (no prefix) - Auto-loaded, use anywhere
2. Private modules (`_` prefix) - Explicit import required
3. Untracked files (git ignored) - Local only

---

## Quality Requirements

**Before commit, all checks pass:**

```bash
alejandra --check .    # or `alejandra .` to auto-fix
statix check .
deadnix --fail .
nix flake check --impure  # when modifying system config
```

**If checks fail:**
- `alejandra --check .` → Run `alejandra .` (auto-fixes)
- `statix check .` → Read error, fix at line:col shown, try `statix fix .`
- `deadnix --fail .` → Remove unused variables from function signatures
- `nix flake check` → Usually import-tree issue, check if files git-added

---

## Commit Format

**Conventional Commits: `<type>(<aspect>): <description>`**

**Types:** feat, fix, refactor, style, docs, chore **Scope:** Aspect name
(module name without `.nix`)

**Examples:**

- `feat(neovim): add LSP support for Rust`
- `fix(hyprland): correct keybind for workspace switching`
- `refactor(desktop): reorganize aggregator imports`

**Commit granularity:** One commit per logical change. Split only when:
- Multiple independent features
- Refactor + new feature (refactor first, then feature)
- User explicitly requests separate commits

---

## Anti-Patterns

**Avoid:**

- ✗ Host-centric organization → Use aspect modules
- ✗ Package-centric modules → Group by purpose, only create modules with
  configuration
- ✗ Manual import management → Trust import-tree
- ✗ Interdependent feature modules → Use aggregators or custom options
- ✗ Skip workflow phases → Follow Explore → Plan → Code → Commit

---

## Quick Reference

### Phase Checkpoint Example

**After Plan:**

> "Implementation plan: [TodoWrite output]
>
> Files to modify: [list] Files to create: [list]
>
> Unresolved questions:
>
> - [question 1]
> - [question 2]
>
> Does this plan look good? Should I proceed to implementation?"

### File Naming

- `{aspect}.nix` - Single-file aspect (`ssh.nix`)
- `{feature}/` - Multi-file feature (`neovim/`)
- `{option}.nix` - Project option (`user.nix`)

---

## Resources

- **Dendritic Principles:** https://vic.github.io/dendrix/Dendritic.html
- **Reference Implementations:**
  - https://github.com/mightyiam/dendritic
  - https://github.com/mightyiam/infra
  - https://github.com/drupol/infra
- **Flake Parts:** https://flake.parts
- **Conventional Commits:** https://www.conventionalcommits.org/

---

## Remember

1. Follow four-phase workflow with checkpoints
2. Use Explore agent for codebase investigation
3. Use TodoWrite to track tasks
4. Wait for approval before code phase
5. `git add` new files immediately
6. Run all checks before commit phase
7. Wait for confirmation before commits
8. Use Conventional Commits with aspect names as scope
9. Preserve aspect-oriented organization
10. Ask questions vs making assumptions
11. Be concise - sacrifice grammar for brevity
12. List unresolved questions at end of plans
13. Check/update TODO.md during planning; commit as `docs(todo)` separately
