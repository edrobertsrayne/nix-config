_: {
  flake.modules.homeManager.neovim = {
    programs.nvf = {
      settings = {
        vim = {
          git = {
            enable = true;
            gitsigns = {
              enable = true;
            };
          };

          keymaps = [
            # === Git hunks ===
            {
              key = "]h";
              mode = "n";
              action = "<cmd>Gitsigns next_hunk<CR>";
              desc = "Next git hunk";
            }
            {
              key = "[h";
              mode = "n";
              action = "<cmd>Gitsigns prev_hunk<CR>";
              desc = "Previous git hunk";
            }
            {
              key = "<leader>gb";
              mode = "n";
              action = "<cmd>Gitsigns blame_line<CR>";
              desc = "Git blame line";
            }
            {
              key = "<leader>gd";
              mode = "n";
              action = "<cmd>Gitsigns diffthis<CR>";
              desc = "Git diff";
            }
            {
              key = "<leader>gh";
              mode = "n";
              action = "<cmd>Gitsigns preview_hunk<CR>";
              desc = "Preview git hunk";
            }
            {
              key = "<leader>gr";
              mode = "n";
              action = "<cmd>Gitsigns reset_hunk<CR>";
              desc = "Reset hunk";
            }
            {
              key = "<leader>gS";
              mode = "n";
              action = "<cmd>Gitsigns stage_buffer<CR>";
              desc = "Stage buffer";
            }
            {
              key = "<leader>gu";
              mode = "n";
              action = "<cmd>Gitsigns undo_stage_hunk<CR>";
              desc = "Undo stage hunk";
            }

            # === LazyGit ===
            {
              key = "<leader>gg";
              mode = "n";
              lua = true;
              action = "function() Snacks.lazygit() end";
              desc = "LazyGit (root)";
            }
            {
              key = "<leader>gG";
              mode = "n";
              lua = true;
              action = "function() Snacks.lazygit({ cwd = vim.fn.getcwd() }) end";
              desc = "LazyGit (cwd)";
            }

            # === Git Browse ===
            {
              key = "<leader>gB";
              mode = "n";
              lua = true;
              action = "function() Snacks.gitbrowse() end";
              desc = "Git Browse (open)";
            }
            {
              key = "<leader>gY";
              mode = "n";
              lua = true;
              action = "function() Snacks.gitbrowse({ open = function(url) vim.fn.setreg('+', url) end }) end";
              desc = "Git Browse (copy)";
            }
          ];
        };
      };
    };
  };
}
