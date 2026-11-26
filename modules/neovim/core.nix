{inputs, ...}: {
  flake.modules.homeManager.neovim = {...}: {
    imports = [inputs.nvf.homeModules.default];

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
            tabstop = 2;
            shiftwidth = 2;
            expandtab = true;
            autoindent = true;
            smartindent = true;
            number = true;
            relativenumber = true;
            ignorecase = true;
            smartcase = true;
            termguicolors = true;
            signcolumn = "yes";
            cursorline = true;
            scrolloff = 8;
            wrap = false;
            mouse = "a";
            clipboard = "unnamedplus";
            undofile = true;
            swapfile = false;
            shortmess = "I";
            foldlevel = 99;
            foldlevelstart = 99;
          };
        };
      };
    };
  };
}
