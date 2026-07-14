_: {
  flake.modules.homeManager.neovim = {pkgs, ...}: {
    programs.nvf = {
      settings = {
        vim = {
          extraPlugins = {
            grug-far-nvim = {
              package = pkgs.vimPlugins.grug-far-nvim;
              setup = ''
                require('grug-far').setup({})
              '';
            };
          };

          keymaps = [
            {
              key = "<leader>sr";
              mode = "n";
              action = "<cmd>lua require('grug-far').open()<CR>";
              desc = "Search and Replace";
            }
            {
              key = "<leader>sR";
              mode = "n";
              action = "<cmd>lua require('grug-far').open({ prefills = { search = vim.fn.expand('<cword>') } })<CR>";
              desc = "Search and Replace (word)";
            }
          ];
        };
      };
    };

    # Ensure ripgrep is available for grug-far to use
    programs.ripgrep.enable = true;
  };
}
