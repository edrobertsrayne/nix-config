_: {
  flake.modules.homeManager.neovim = {
    programs.nvf = {
      settings = {
        vim.keymaps = [
          # === Save ===
          {
            key = "<leader>w";
            mode = "n";
            action = ":w<CR>";
            desc = "Save file";
          }
          {
            key = "<C-s>";
            mode = "n";
            action = ":w<CR>";
            desc = "Save file";
          }

          # === Buffer management ===
          {
            key = "<leader>bd";
            mode = "n";
            action = ":bdelete<CR>";
            desc = "Delete buffer";
          }
          {
            key = "<leader>bb";
            mode = "n";
            action = "<cmd>e #<CR>";
            desc = "Switch to alternate buffer";
          }
          {
            key = "<leader>bo";
            mode = "n";
            action = "<cmd>%bd|e#|bd#<CR>";
            desc = "Delete other buffers";
          }
          {
            key = "<leader>bD";
            mode = "n";
            action = "<cmd>bd<CR><cmd>close<CR>";
            desc = "Delete buffer and window";
          }
          {
            key = "<S-h>";
            mode = "n";
            action = ":bprevious<CR>";
            desc = "Previous buffer";
          }
          {
            key = "<S-l>";
            mode = "n";
            action = ":bnext<CR>";
            desc = "Next buffer";
          }
          {
            key = "[b";
            mode = "n";
            action = ":bprevious<CR>";
            desc = "Previous buffer";
          }
          {
            key = "]b";
            mode = "n";
            action = ":bnext<CR>";
            desc = "Next buffer";
          }

          # === Window management ===
          {
            key = "<leader>wd";
            mode = "n";
            action = "<C-w>c";
            desc = "Delete/close window";
          }
          {
            key = "<leader>-";
            mode = "n";
            action = "<C-w>s";
            desc = "Split window horizontally";
          }
          {
            key = "<leader>|";
            mode = "n";
            action = "<C-w>v";
            desc = "Split window vertically";
          }

          # === Window resize ===
          {
            key = "<C-Up>";
            mode = "n";
            action = ":resize +2<CR>";
            desc = "Increase window height";
          }
          {
            key = "<C-Down>";
            mode = "n";
            action = ":resize -2<CR>";
            desc = "Decrease window height";
          }
          {
            key = "<C-Left>";
            mode = "n";
            action = ":vertical resize -2<CR>";
            desc = "Decrease window width";
          }
          {
            key = "<C-Right>";
            mode = "n";
            action = ":vertical resize +2<CR>";
            desc = "Increase window width";
          }

          # === Better n/N (center search results) ===
          {
            key = "n";
            mode = "n";
            action = "nzzzv";
            desc = "Next search result";
          }
          {
            key = "N";
            mode = "n";
            action = "Nzzzv";
            desc = "Previous search result";
          }

          # === Clear search highlights ===
          {
            key = "<Esc>";
            mode = "n";
            action = ":noh<CR><Esc>";
            desc = "Clear search highlights";
          }

          # === Insert mode ===
          {
            key = "jk";
            mode = "i";
            action = "<Esc>";
            desc = "Exit insert mode";
          }
          {
            key = "<C-s>";
            mode = "i";
            action = "<Esc>:w<CR>a";
            desc = "Save file";
          }

          # === Move lines in insert mode ===
          {
            key = "<A-j>";
            mode = "i";
            action = "<Esc>:m .+1<CR>==gi";
            desc = "Move line down";
          }
          {
            key = "<A-k>";
            mode = "i";
            action = "<Esc>:m .-2<CR>==gi";
            desc = "Move line up";
          }

          # === Visual mode — keep selection after indent ===
          {
            key = "<";
            mode = "v";
            action = "<gv";
            desc = "Indent left";
          }
          {
            key = ">";
            mode = "v";
            action = ">gv";
            desc = "Indent right";
          }

          # === Move lines in visual mode ===
          {
            key = "J";
            mode = "v";
            action = ":m '>+1<CR>gv=gv";
            desc = "Move line down";
          }
          {
            key = "K";
            mode = "v";
            action = ":m '<-2<CR>gv=gv";
            desc = "Move line up";
          }
          {
            key = "<A-j>";
            mode = "v";
            action = ":m '>+1<CR>gv=gv";
            desc = "Move line down";
          }
          {
            key = "<A-k>";
            mode = "v";
            action = ":m '<-2<CR>gv=gv";
            desc = "Move line up";
          }
        ];
      };
    };
  };
}
