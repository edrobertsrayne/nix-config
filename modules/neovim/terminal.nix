_: {
  flake.modules.homeManager.neovim = {
    programs.nvf = {
      settings = {
        vim = {
          terminal = {
            toggleterm = {
              enable = false;
            };
          };

          keymaps = [
            {
              key = "<Esc><Esc>";
              mode = "t";
              action = "<C-\\><C-n>";
              desc = "Exit terminal mode";
            }
          ];
        };
      };
    };
  };
}
