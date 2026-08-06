_: {
  flake.modules.homeManager.utilities = {pkgs, ...}: {
    home.shellAliases = {
      tmux = "tmux a || tmux";
    };

    programs.tmux = {
      enable = true;

      plugins = with pkgs.tmuxPlugins; [
        sensible
        {
          plugin = resurrect;
          extraConfig = ''
            set -g @resurrect-strategy-vim 'session'
            set -g @resurrect-strategy-nvim 'session'
            set -g @resurrect-capture-pane-contents 'on'
          '';
        }
        {
          plugin = continuum;
          extraConfig = ''
            set -g @continuum-restore 'on'
            set -g @continuum-save-interval '15'
          '';
        }
        vim-tmux-navigator
        tokyo-night-tmux
      ];

      sensibleOnTop = true;
      prefix = "C-s";
      mouse = true;
      keyMode = "vi";
      escapeTime = 0;
      focusEvents = true;
      historyLimit = 50000;
      baseIndex = 1;

      # Custom configuration
      extraConfig = ''
        unbind '"'
        unbind %
        bind | split-window -h -c "#{pane_current_path}"
        bind - split-window -v -c "#{pane_current_path}"

        # Smart pane switching with awareness of Vim splits
        # Note: vim-tmux-navigator plugin handles integration with Neovim
        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R

        # Use Shift+Arrow keys to switch windows (no prefix needed)
        bind -n S-Left previous-window
        bind -n S-Right next-window

        # Renumber windows when one is closed
        set -g renumber-windows on

        # Display pane indicators for longer
        set -g display-panes-time 2000

        # Highlight current window in status bar
        setw -g window-status-current-style 'fg=colour0,bg=colour1,bold'

        # Enable 256 color support
        set -g default-terminal "screen-256color"
        set -ga terminal-overrides ",*256col*:Tc"

        # Reload configuration with prefix + r
        bind r source-file ~/.config/tmux/tmux.conf \; display "Configuration reloaded!"
      '';
    };
  };
}
