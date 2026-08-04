{inputs, ...}: {
  flake.modules.homeManager.neovim = {...}: {
    imports = [inputs.nvf.homeManagerModules.default];

    home.shellAliases = {
      n = "nvim";
    };

    programs.nvf = {
      enable = true;
      settings = {
        vim = {
          viAlias = true;
          vimAlias = true;

          theme = {
            enable = true;
            name = "tokyonight";
            style = "night";
            transparent = true;
          };

          options = {
            tabstop = 2; # Tab character displays as 2 spaces
            shiftwidth = 2; # Indent/dedent by 2 spaces
            expandtab = true; # Use spaces instead of tab characters
            autoindent = true;
            smartindent = true;
            number = true; # Show absolute line numbers
            relativenumber = true; # Show relative line numbers (great for motion commands like 5j)
            ignorecase = true; # Case-insensitive search...
            smartcase = true; # ...unless search contains uppercase letters
            termguicolors = true; # Enable 24-bit RGB colors
            signcolumn = "yes"; # Always show sign column (prevents text shifting when signs appear)
            cursorline = true; # Highlight the current line
            scrolloff = 8; # Keep 8 lines visible above/below cursor when scrolling
            wrap = false; # Don't wrap long lines
            mouse = "a"; # Enable mouse support in all modes
            clipboard = "unnamedplus"; # Use system clipboard
            undofile = true; # Persistent undo history across sessions
            swapfile = false; # Disable swap files (we have persistent undo)
            shortmess = "I"; # Disable the introductory message
            foldlevel = 99; # Open all folds by default (treesitter folding is on)
            foldlevelstart = 99; # ...including every newly opened buffer
          };
        };
      };
    };
  };
}
