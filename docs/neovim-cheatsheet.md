# Neovim Cheatsheet - Niflheim Configuration

## Quick Reference Card

**Most Used Commands**:

```text
<Space>         Leader key
<leader>w       Save file
<leader><leader> Find files
<leader>/       Find text (grep)
<leader>e       Toggle file tree
Ctrl+`          Toggle terminal
K               Hover documentation
gd              Go to definition
<leader>ca      Code actions
jk              Exit insert mode
```

**Important Notes**:

- **Leader Key**: `Space` is the leader key for most commands
- **Based on nvf**: Uses the Neovim configuration framework
- **LSP-Powered**: Full language server support with format on save
- **Tokyo Night Theme**: Consistent with system-wide theming
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
| `<leader>,` | Find buffers (Telescope) |
| `<leader>fb` | Find buffers (Telescope) |

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

## Telescope (Fuzzy Finder)

### File Finding

| Shortcut | Action |
|----------|--------|
| `<leader><leader>` | Find files |
| `<leader>ff` | Find files |
| `<leader>fr` | Find recent files (oldfiles) |

### Search Operations

| Shortcut | Action |
|----------|--------|
| `<leader>/` | Find text (live grep) |
| `<leader>fg` | Find text (live grep) |
| `<leader>fs` | Find symbols (LSP document symbols) |

### Buffers & History

| Shortcut | Action |
|----------|--------|
| `<leader>,` | Find buffers |
| `<leader>fb` | Find buffers |
| `<leader>:` | Command history |

**Telescope Navigation** (when picker is open):
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
| `<leader>gp` | Preview git hunk |
| `<leader>gr` | Reset hunk |
| `<leader>gS` | Stage buffer |
| `<leader>gu` | Undo stage hunk |

### Git Information

| Shortcut | Action |
|----------|--------|
| `<leader>gb` | Git blame line |
| `<leader>gd` | Git diff |

**Features**:
- Gitsigns shows added/changed/removed lines in sign column
- Lazygit integration available via toggleterm

---

## Terminal Integration

### Toggleterm

| Shortcut | Mode | Action |
|----------|------|--------|
| `Ctrl+\`` | Normal | Toggle terminal |
| `Ctrl+\`` | Terminal | Hide terminal |
| `Esc Esc` | Terminal | Exit terminal mode |

**Features**:
- Persistent terminal sessions
- Lazygit integration available
- Terminal appears as floating window

---

## File Tree (NeoTree)

| Shortcut | Action |
|----------|--------|
| `<leader>e` | Toggle NeoTree file explorer |

**NeoTree Navigation** (when open):
- `j/k` - Navigate up/down
- `Enter` - Open file/folder
- `h` - Collapse folder
- `l` - Expand folder
- `a` - Add file/folder
- `d` - Delete file/folder
- `r` - Rename file/folder
- `q` - Close NeoTree

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

- **Tokyo Night** theme (matches system-wide Stylix theme)
- Style: Default Tokyo Night variant
- Transparent background: Configured via theme settings
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
- **Telescope**: Fuzzy finder and picker
- **NeoTree**: File explorer
- **Gitsigns**: Git integration
- **Toggleterm**: Terminal management
- **Tmux Navigator**: Seamless vim-tmux navigation
- **Grug-far**: Search and replace interface
- **LSP/Treesitter**: Language support and syntax highlighting

---

## Tips & Tricks

1. **Modal Editing**: Embrace Vim's modes - stay in normal mode, use motions for navigation
2. **Leader Mappings**: Most custom commands use `<Space>` as leader - easy to remember and access
3. **Persistent Undo**: Your undo history persists across sessions - you can undo even after reopening files
4. **LSP Integration**: Hover with `K`, jump to definition with `gd`, code actions with `<leader>ca`
5. **Fuzzy Finding**: `<leader><leader>` for files, `<leader>/` for text - fastest way to navigate
6. **Terminal Access**: `Ctrl+\`` toggles a terminal without leaving Neovim
7. **Git Workflow**: Use gitsigns for quick hunk operations, staging, and blame
8. **Tmux Integration**: Navigate seamlessly between vim splits and tmux panes with `Ctrl+h/j/k/l`
9. **Format on Save**: Code is automatically formatted when you save (`:w`)
10. **System Clipboard**: Yank and paste work with system clipboard (no need for `"+y`)

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
- `terminal.nix` - Terminal integration (toggleterm, lazygit)
- `filetree.nix` - File explorer (NeoTree)
- `grug-far.nix` - Search and replace
- `tmux-navigator.nix` - Vim-tmux navigation integration
- `diagnostics.nix` - Diagnostics and error display
- `ui.nix`, `visuals.nix`, `editor.nix`, `navigation.nix`, `completion.nix`, `treesitter.nix`, `mini.nix` - Additional features

**Actual config**: Managed by home-manager and nvf framework

---

## Additional Resources

- **nvf Documentation**: <https://notashelf.github.io/nvf/>
- **Neovim Docs**: <https://neovim.io/doc/>
- **Telescope**: <https://github.com/nvim-telescope/telescope.nvim>
- **NeoTree**: <https://github.com/nvim-neo-tree/neo-tree.nvim>
- **Learn Vim**: `:Tutor` command for interactive Vim tutorial
