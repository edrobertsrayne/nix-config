# Neovim Cheatsheet

## Quick Reference Card

**Most Used Commands**:

```text
<Space>          Leader key
<leader>w        Save file
<leader><space>  Find files
<leader>/        Find text (grep)
<leader>e        Toggle file explorer
<leader>gg       LazyGit
K                Hover documentation
gd               Go to definition
<leader>ca       Code actions
jk               Exit insert mode
```

**Important Notes**:

- **Leader Key**: `Space` is the leader key for most commands
- **Based on nvf**: Uses the Neovim configuration framework
- **snacks.nvim**: Provides the picker, explorer, terminal and LazyGit —
  Telescope, NeoTree and toggleterm are all disabled
- **which-key**: Pause after `<leader>` and the available follow-ups appear
- **LSP-Powered**: Full language server support with format on save
- **Tokyo Night Theme**: Matches the tmux status bar
- **Modal Editing**: Embraces Vim's powerful modal paradigm

---

## File Operations

### Saving Files

| Shortcut | Mode | Action |
|----------|------|--------|
| `<leader>w` | Normal | Save file |
| `Ctrl+s` | Normal | Save file |
| `Ctrl+s` | Insert | Save and return to insert mode |

---

## Buffer Management

### Navigation

| Shortcut | Action |
|----------|--------|
| `Shift+h` | Previous buffer |
| `Shift+l` | Next buffer |
| `[b` | Previous buffer (alternative) |
| `]b` | Next buffer (alternative) |
| `<leader>bb` | Switch to alternate buffer (last viewed) |

### Buffer Operations

| Shortcut | Action |
|----------|--------|
| `<leader>bd` | Delete current buffer |
| `<leader>bD` | Delete buffer and close window |
| `<leader>bo` | Delete all other buffers (keep current) |
| `<leader>,` | Find buffers |
| `<leader>fb` | Find buffers |

---

## Window Management

### Window Splits

| Shortcut | Action |
|----------|--------|
| `<leader>-` | Split window horizontally |
| `<leader>\|` | Split window vertically |
| `<leader>wd` | Delete/close window |

### Window Navigation

**Integrated with Tmux**: Use `Ctrl+h/j/k/l` to navigate seamlessly between Neovim splits and tmux panes (via tmux-navigator plugin).

### Window Resizing

| Shortcut | Action |
|----------|--------|
| `Ctrl+Up` | Increase window height |
| `Ctrl+Down` | Decrease window height |
| `Ctrl+Left` | Decrease window width |
| `Ctrl+Right` | Increase window width |

**Note**: Each resize operation changes dimensions by 2 units.

---

## LSP (Language Server Protocol)

### Quick Navigation

| Shortcut | Action |
|----------|--------|
| `K` | Hover documentation |
| `gK` | Signature help |
| `gd` | Go to definition |
| `gD` | Go to declaration |
| `gr` | Go to references |
| `gI` | Go to implementation |
| `gy` | Go to type definition |

### Code Operations

| Shortcut | Mode | Action |
|----------|------|--------|
| `<leader>ca` | Normal/Visual | Code actions |
| `<leader>cr` | Normal | Rename symbol |
| `<leader>cf` | Normal/Visual | Format code/selection |
| `<leader>cd` | Normal | Show line diagnostics |
| `<leader>ch` | Normal | Hover documentation |
| `<Ctrl+k>` | Insert | Signature help |

### Diagnostics Navigation

| Shortcut | Action |
|----------|--------|
| `]d` | Next diagnostic |
| `[d` | Previous diagnostic |
| `]e` | Next error |
| `[e` | Previous error |
| `]w` | Next warning |
| `[w` | Previous warning |

**Features**:
- Format on save enabled by default
- LSP lightbulb shows available code actions
- Virtual text shows diagnostic messages inline

---

## Pickers (snacks.nvim)

Fuzzy finding is `Snacks.picker` (`modules/neovim/utility.nix`). Telescope is
installed by nvf but explicitly disabled.

Most pickers come in a pair: lowercase searches from the **project root**,
uppercase from the **current working directory**.

### File Finding

| Shortcut | Action |
|----------|--------|
| `<leader><space>` | Find files (root) |
| `<leader>ff` | Find files (root) |
| `<leader>fF` | Find files (cwd) |
| `<leader>fg` | Git files |
| `<leader>fr` | Recent files |
| `<leader>fR` | Recent files (cwd) |

### Search Operations

| Shortcut | Action |
|----------|--------|
| `<leader>/` | Grep (root) |
| `<leader>sg` | Grep (root) |
| `<leader>sG` | Grep (cwd) |

### Buffers & History

| Shortcut | Action |
|----------|--------|
| `<leader>,` | Buffers |
| `<leader>fb` | Buffers |
| `<leader>:` | Command history |
| `<leader>s/` | Search history |

### GitHub

Requires `gh` to be authenticated.

| Shortcut | Action |
|----------|--------|
| `<leader>gi` / `<leader>gI` | GitHub issues — open / all |
| `<leader>gp` / `<leader>gP` | GitHub pull requests — open / all |

**Picker Navigation** (when open):
- `Ctrl+n` / `Ctrl+j` - Next item
- `Ctrl+p` / `Ctrl+k` - Previous item
- `Enter` - Select item
- `Esc` - Close picker

---

## Git Integration

### Git Hunks (Gitsigns)

| Shortcut | Action |
|----------|--------|
| `]h` | Next git hunk |
| `[h` | Previous git hunk |
| `<leader>gh` | Preview git hunk |
| `<leader>gr` | Reset hunk |
| `<leader>gS` | Stage buffer |
| `<leader>gu` | Undo stage hunk |

### Git Information

| Shortcut | Action |
|----------|--------|
| `<leader>gb` | Git blame line |
| `<leader>gd` | Git diff |

### LazyGit and Browse

| Shortcut | Action |
|----------|--------|
| `<leader>gg` | LazyGit (root) |
| `<leader>gG` | LazyGit (cwd) |
| `<leader>gB` | Open this line on GitHub |
| `<leader>gY` | Copy the GitHub URL for this line |

**Features**:
- Gitsigns shows added/changed/removed lines in sign column
- LazyGit opens in a snacks float, not a toggleterm

---

## Terminal Integration

The terminal is `Snacks.terminal`; toggleterm is disabled.

| Shortcut | Mode | Action |
|----------|------|--------|
| `Ctrl+/` | Terminal | Toggle terminal |
| `Esc Esc` | Terminal | Exit terminal mode (back to normal) |

**Features**:
- Terminal appears as a floating window
- LazyGit has its own binding, `<leader>gg`

---

## File Explorer (snacks.nvim)

NeoTree is installed by nvf but explicitly disabled; the explorer is
`Snacks.explorer`.

| Shortcut | Action |
|----------|--------|
| `<leader>e` | Explorer (root) |
| `<leader>E` | Explorer (cwd) |

**Explorer Navigation** (when open):
- `j/k` - Navigate up/down
- `Enter` - Open file/folder
- `a` - Add file/folder
- `d` - Delete file/folder
- `r` - Rename file/folder
- `q` - Close explorer

---

## Search and Replace (grug-far)

| Shortcut | Action |
|----------|--------|
| `<leader>sr` | Open search and replace interface |
| `<leader>sR` | Search and replace current word |

**Features**:
- Powered by ripgrep for fast searching
- Interactive interface with preview
- Project-wide find and replace

---

## Editing Shortcuts

### Insert Mode

| Shortcut | Action |
|----------|--------|
| `jk` | Exit insert mode (to normal mode) |
| `Alt+j` | Move line down |
| `Alt+k` | Move line up |

### Visual Mode

| Shortcut | Action |
|----------|--------|
| `<` | Indent left (keeps selection) |
| `>` | Indent right (keeps selection) |
| `J` | Move line down |
| `K` | Move line up |
| `Alt+j` | Move line down |
| `Alt+k` | Move line up |

### Search

| Shortcut | Action |
|----------|--------|
| `n` | Next search result (centered) |
| `N` | Previous search result (centered) |
| `Esc` | Clear search highlights |

**Features**:
- Case-insensitive search by default
- Smart case: becomes case-sensitive if search contains uppercase
- Search results are automatically centered on screen

---

## Language Support

### Enabled Languages

| Language | LSP | Format | Diagnostics | Features |
|----------|-----|--------|-------------|----------|
| **Nix** | ✅ | ✅ alejandra | ✅ statix, deadnix | Full support with extra diagnostics |
| **Markdown** | ✅ | ✅ | ✅ | Documentation editing |
| **Python** | ✅ | ✅ | ✅ | Python development |
| **CSS** | ✅ | ✅ | ✅ | Stylesheet editing |
| **Bash** | ✅ | ✅ | ✅ | Shell scripting |

**Features**:
- Treesitter syntax highlighting enabled for all languages
- Format on save enabled
- DAP (Debug Adapter Protocol) support enabled
- Extra diagnostics for Nix (statix linting, deadnix unused code detection)

---

## Editor Options

**Key Settings**:

| Setting | Value | Description |
|---------|-------|-------------|
| Tab width | 2 spaces | Consistent indentation |
| Line numbers | Hybrid (absolute + relative) | Efficient motion commands |
| Cursor line | Enabled | Current line highlighting |
| Scroll offset | 8 lines | Context above/below cursor |
| Mouse | Enabled (all modes) | Optional mouse support |
| Clipboard | System clipboard | Easy copy/paste |
| Undo file | Persistent | Undo history across sessions |
| Swap file | Disabled | No swap files created |
| Word wrap | Disabled | Long lines scroll horizontally |

---

## Visual Features

### Theme

- **Tokyo Night** theme, `night` style (`modules/neovim/core.nix`) — the same
  family as the tmux status bar, which uses `tokyo-night-tmux`
- Transparent background
- True color (24-bit RGB) support

### UI Enhancements

- **Sign column**: Always visible (prevents text shifting)
- **Relative line numbers**: Great for motion commands (e.g., `5j` to move 5 lines down)
- **Cursorline**: Highlights current line
- **Rainbow delimiters**: Enabled for matching brackets/parentheses
- **Gitsigns**: Shows git changes in sign column

---

## Additional Plugins

### Installed Plugins

- **nvf**: Neovim configuration framework
- **snacks.nvim**: Picker, explorer, terminal, LazyGit, notifier, zen mode,
  scratch buffers, indent guides, smooth scrolling
- **Gitsigns**: Git integration
- **which-key**: Shows available keys after a prefix
- **mini.nvim**: `ai` (textobjects), `surround` (`gsa`/`gsd`/`gsr`), `pairs`,
  `comment`, `icons`
- **Tmux Navigator**: Seamless vim-tmux navigation
- **Grug-far**: Search and replace interface
- **hop**: Jump-to-anywhere motions
- **todo-comments**: Highlights TODO/FIXME
- **LSP/Treesitter**: Language support and syntax highlighting

Installed by nvf but **deliberately disabled**: Telescope, NeoTree, toggleterm —
snacks.nvim replaces all three.

---

## Tips & Tricks

1. **Modal Editing**: Embrace Vim's modes - stay in normal mode, use motions for navigation
2. **Leader Mappings**: Most custom commands use `<Space>` as leader - easy to remember and access
3. **Persistent Undo**: Your undo history persists across sessions - you can undo even after reopening files
4. **LSP Integration**: Hover with `K`, jump to definition with `gd`, code actions with `<leader>ca`
5. **Fuzzy Finding**: `<leader><space>` for files, `<leader>/` for text - fastest way to navigate
6. **Root vs cwd**: Lowercase picker bindings search the project root, uppercase the current directory
7. **Git Workflow**: Gitsigns for hunks and blame, `<leader>gg` for LazyGit
8. **Forgot a binding?**: Press `<leader>` and wait - which-key lists what's available
9. **Tmux Integration**: Navigate seamlessly between vim splits and tmux panes with `Ctrl+h/j/k/l`
10. **Format on Save**: Code is automatically formatted when you save (`:w`)
11. **System Clipboard**: Yank and paste work with system clipboard (no need for `"+y`)

---

## Configuration Location

**Config managed via**: `modules/neovim/` (modular structure)

**Key modules**:
- `core.nix` - Core editor settings and options
- `keymaps.nix` - Keyboard shortcuts and bindings
- `lsp.nix` - Language server configuration
- `languages.nix` - Language-specific settings (Nix, Python, CSS, Bash, Markdown)
- `telescope.nix` - Fuzzy finder configuration
- `git.nix` - Git integration (gitsigns)
- `terminal.nix` - Terminal keymaps (toggleterm is disabled here)
- `filetree.nix` - Disables NeoTree in favour of the snacks explorer
- `grug-far.nix` - Search and replace
- `tmux-navigator.nix` - Vim-tmux navigation integration
- `diagnostics.nix` - Diagnostics and error display
- `ui.nix`, `visuals.nix`, `editor.nix`, `navigation.nix`, `completion.nix`, `treesitter.nix`, `mini.nix`, `utility.nix` - Additional features

Edit those and rebuild. The generated Neovim config is a read-only symlink into
the Nix store, written by home-manager from nvf — there is no `init.lua` to
edit.

---

## Additional Resources

- **nvf Documentation**: <https://notashelf.github.io/nvf/>
- **Neovim Docs**: <https://neovim.io/doc/>
- **snacks.nvim**: <https://github.com/folke/snacks.nvim>
- **mini.nvim**: <https://github.com/echasnovski/mini.nvim>
- **Learn Vim**: `:Tutor` command for interactive Vim tutorial
