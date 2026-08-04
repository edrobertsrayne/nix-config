# Tmux Cheatsheet - Niflheim Configuration

## Quick Reference Card

**Most Used Commands**:
```
Ctrl+s |          Split horizontally
Ctrl+s -          Split vertically
Ctrl+s h/j/k/l    Navigate panes (vim-style)
Shift+Left/Right  Switch windows
Ctrl+s z          Zoom pane
Ctrl+s [          Copy mode
Ctrl+s d          Detach session
Ctrl+s r          Reload config
```

**Important Notes**:
- **Custom Prefix**: This configuration uses `Ctrl+s` instead of the default `Ctrl+b`
- **Vi Mode**: Enabled for copy mode navigation
- **Mouse Support**: Click, drag, and scroll enabled
- **Base Index**: Windows and panes start at 1 (not 0)

---

## Custom Keybindings

### Pane Splitting (Custom)
| Shortcut | Action |
|----------|--------|
| `Ctrl+s \|` | Split pane horizontally (side-by-side) |
| `Ctrl+s -` | Split pane vertically (stacked) |

### Pane Navigation (Custom)
| Shortcut | Action |
|----------|--------|
| `Ctrl+s h` | Select pane to the left |
| `Ctrl+s j` | Select pane below |
| `Ctrl+s k` | Select pane above |
| `Ctrl+s l` | Select pane to the right |

**Note**: The vim-tmux-navigator plugin enables seamless navigation between Neovim splits and tmux panes using the same `Ctrl+h/j/k/l` keys.

### Window Navigation (No Prefix Required)
| Shortcut | Action |
|----------|--------|
| `Shift+Left` | Previous window |
| `Shift+Right` | Next window |

### Configuration Management
| Shortcut | Action |
|----------|--------|
| `Ctrl+s r` | Reload tmux configuration |

---

## Session Management

| Shortcut | Action |
|----------|--------|
| `Ctrl+s $` | Rename current session |
| `Ctrl+s d` | Detach from session |
| `Ctrl+s s` | List all sessions |
| `Ctrl+s w` | Session and window preview |
| `Ctrl+s (` | Move to previous session |
| `Ctrl+s )` | Move to next session |

**Terminal Commands**:
```bash
tmux                          # Start new session
tmux new -s <name>            # Start new named session
tmux ls                       # List sessions
tmux attach -t <name>         # Attach to named session
tmux kill-session -t <name>   # Kill named session
```

---

## Window Management

| Shortcut | Action |
|----------|--------|
| `Ctrl+s c` | Create new window |
| `Ctrl+s ,` | Rename current window |
| `Ctrl+s &` | Close current window |
| `Ctrl+s w` | List windows |
| `Ctrl+s p` | Previous window |
| `Ctrl+s n` | Next window |
| `Ctrl+s 0-9` | Switch to window by number |
| `Ctrl+s l` | Toggle last active window |
| `Shift+Left` | Previous window (no prefix) |
| `Shift+Right` | Next window (no prefix) |

**Features**:
- Windows automatically renumber when one is closed
- Current window highlighted in status bar

---

## Pane Management

### Splitting
| Shortcut | Action |
|----------|--------|
| `Ctrl+s \|` | Split horizontally (custom) |
| `Ctrl+s -` | Split vertically (custom) |

### Navigation
| Shortcut | Action |
|----------|--------|
| `Ctrl+s h/j/k/l` | Select pane (vim-style, custom) |
| `Ctrl+s ↑/↓/←/→` | Select pane (arrow keys) |
| `Ctrl+s ;` | Toggle last active pane |
| `Ctrl+s o` | Switch to next pane |
| `Ctrl+s q` | Show pane numbers (2 second display) |

### Layout & Organization
| Shortcut | Action |
|----------|--------|
| `Ctrl+s Spacebar` | Cycle through pane layouts |
| `Ctrl+s {` | Move current pane left |
| `Ctrl+s }` | Move current pane right |
| `Ctrl+s z` | Toggle pane zoom (fullscreen) |
| `Ctrl+s !` | Convert pane to window |
| `Ctrl+s x` | Close current pane |

---

## Copy Mode (Vi Mode Enabled)

### Entering Copy Mode
| Shortcut | Action |
|----------|--------|
| `Ctrl+s [` | Enter copy mode |
| `Ctrl+s PgUp` | Enter copy mode and scroll up |

### Navigation (Vi Keys)
| Shortcut | Action |
|----------|--------|
| `h/j/k/l` | Move cursor left/down/up/right |
| `w` | Move forward one word |
| `b` | Move backward one word |
| `0` | Move to start of line |
| `$` | Move to end of line |
| `g` | Go to top of buffer |
| `G` | Go to bottom of buffer |
| `Ctrl+u` | Scroll up half page |
| `Ctrl+d` | Scroll down half page |

### Searching
| Shortcut | Action |
|----------|--------|
| `/` | Search forward |
| `?` | Search backward |
| `n` | Next search result |
| `N` | Previous search result |

### Selecting & Copying
| Shortcut | Action |
|----------|--------|
| `Spacebar` | Start selection |
| `Enter` | Copy selection |
| `Esc` | Clear selection |
| `q` | Quit copy mode |

### Pasting
| Shortcut | Action |
|----------|--------|
| `Ctrl+s ]` | Paste buffer contents |

---

## Plugin Features

### Tmux Resurrect
Automatically saves and restores tmux sessions.

**Configuration**:
- Vim/Neovim sessions are saved
- Pane contents are captured
- Auto-restore enabled via continuum

**Manual Commands**:
| Shortcut | Action |
|----------|--------|
| `Ctrl+s Ctrl+s` | Save session |
| `Ctrl+s Ctrl+r` | Restore session |

### Tmux Continuum
Automatic session saving and restoration.

**Features**:
- Auto-saves every 15 minutes
- Auto-restores last session on tmux start
- Works seamlessly with resurrect

### Vim Tmux Navigator
Seamless navigation between Neovim and tmux panes.

**Usage**:
- `Ctrl+h/j/k/l` - Navigate between vim splits and tmux panes
- No prefix needed when in Neovim
- Automatic detection of vim/tmux boundaries

---

## Miscellaneous

| Shortcut | Action |
|----------|--------|
| `Ctrl+s :` | Enter command mode |
| `Ctrl+s ?` | List all key bindings |
| `Ctrl+s t` | Show clock |
| `Ctrl+s i` | Display pane information |

---

## Mouse Support

**Enabled Features**:
- Click to select pane
- Click to select window (in status bar)
- Drag to resize panes
- Scroll to navigate history
- Double-click to select word
- Triple-click to select line

---

## Terminal Features

**Capabilities**:
- 256-color support enabled
- True color (24-bit) support
- Escape time: 0ms (instant)
- Focus events enabled
- History limit: 50,000 lines

---

## Tips

1. **Sessions persist**: Tmux sessions continue running after detaching - perfect for long-running tasks
2. **Resurrect/Continuum**: Your sessions auto-save every 15 minutes and restore on tmux startup
3. **Vim integration**: Use `Ctrl+h/j/k/l` seamlessly between Neovim and tmux
4. **Mouse works**: Don't forget you can click and drag with mouse support enabled
5. **Base index 1**: Windows and panes start at 1 (matching keyboard number row)
6. **Nord theme**: Status bar uses Nord color scheme for consistency with other tools

---

## Configuration Location

Config managed via: `modules/utilities/tmux.nix`

Actual config file: `~/.config/tmux/tmux.conf`
