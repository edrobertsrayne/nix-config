_: {
  flake.modules.homeManager.neovim = {
    programs.nvf = {
      settings = {
        vim = {
          utility = {
            snacks-nvim = {
              enable = true;
              setupOpts = {
                bigfile.enabled = true;
                quickfile.enabled = true;
                notifier.enabled = true;
                picker.enabled = true;
                terminal.enabled = true;
                indent.enabled = true;
                scroll.enabled = true;
                explorer.enabled = true;
                zen.enabled = true;
                scratch.enabled = true;
                lazygit.enabled = true;
                gitbrowse.enabled = true;
                bufdelete.enabled = true;
                rename.enabled = true;
                words.enabled = true;
                statuscolumn.enabled = true;
                dim.enabled = true;
                input.enabled = true;
                toggle.enabled = true;
                scope.enabled = true;
                win.enabled = true;
              };
            };
          };

          keymaps = [
            # GitHub pickers
            {
              key = "<leader>gi";
              mode = "n";
              lua = true;
              action = "function() Snacks.picker.gh_issue() end";
              desc = "GitHub Issues (open)";
            }
            {
              key = "<leader>gI";
              mode = "n";
              lua = true;
              action = "function() Snacks.picker.gh_issue({ state = \"all\" }) end";
              desc = "GitHub Issues (all)";
            }
            {
              key = "<leader>gp";
              mode = "n";
              lua = true;
              action = "function() Snacks.picker.gh_pr() end";
              desc = "GitHub Pull Requests (open)";
            }
            {
              key = "<leader>gP";
              mode = "n";
              lua = true;
              action = "function() Snacks.picker.gh_pr({ state = \"all\" }) end";
              desc = "GitHub Pull Requests (all)";
            }

            # File pickers
            {
              key = "<leader><space>";
              mode = "n";
              lua = true;
              action = "function() Snacks.picker.files() end";
              desc = "Find Files (root)";
            }
            {
              key = "<leader>ff";
              mode = "n";
              lua = true;
              action = "function() Snacks.picker.files() end";
              desc = "Find Files (root)";
            }
            {
              key = "<leader>fF";
              mode = "n";
              lua = true;
              action = "function() Snacks.picker.files({ cwd = vim.fn.getcwd() }) end";
              desc = "Find Files (cwd)";
            }
            {
              key = "<leader>fg";
              mode = "n";
              lua = true;
              action = "function() Snacks.picker.git_files() end";
              desc = "Git Files";
            }
            {
              key = "<leader>fb";
              mode = "n";
              lua = true;
              action = "function() Snacks.picker.buffers() end";
              desc = "Buffers";
            }
            {
              key = "<leader>,";
              mode = "n";
              lua = true;
              action = "function() Snacks.picker.buffers() end";
              desc = "Buffers";
            }
            {
              key = "<leader>fr";
              mode = "n";
              lua = true;
              action = "function() Snacks.picker.recent() end";
              desc = "Recent Files";
            }
            {
              key = "<leader>fR";
              mode = "n";
              lua = true;
              action = "function() Snacks.picker.recent({ cwd = vim.fn.getcwd() }) end";
              desc = "Recent Files (cwd)";
            }

            # Grep/search
            {
              key = "<leader>/";
              mode = "n";
              lua = true;
              action = "function() Snacks.picker.grep() end";
              desc = "Grep (root)";
            }
            {
              key = "<leader>sg";
              mode = "n";
              lua = true;
              action = "function() Snacks.picker.grep() end";
              desc = "Grep (root)";
            }
            {
              key = "<leader>sG";
              mode = "n";
              lua = true;
              action = "function() Snacks.picker.grep({ cwd = vim.fn.getcwd() }) end";
              desc = "Grep (cwd)";
            }

            # History
            {
              key = "<leader>:";
              mode = "n";
              lua = true;
              action = "function() Snacks.picker.command_history() end";
              desc = "Command History";
            }
            {
              key = "<leader>s/";
              mode = "n";
              lua = true;
              action = "function() Snacks.picker.search_history() end";
              desc = "Search History";
            }

            # Explorer
            {
              key = "<leader>e";
              mode = "n";
              lua = true;
              action = "function() Snacks.explorer() end";
              desc = "Explorer (root)";
            }
            {
              key = "<leader>E";
              mode = "n";
              lua = true;
              action = "function() Snacks.explorer({ cwd = vim.fn.getcwd() }) end";
              desc = "Explorer (cwd)";
            }

            # Notifications & scratch
            {
              key = "<leader>n";
              mode = "n";
              lua = true;
              action = "function() Snacks.notifier.show_history() end";
              desc = "Notification History";
            }
            {
              key = "<leader>un";
              mode = "n";
              lua = true;
              action = "function() Snacks.notifier.hide() end";
              desc = "Dismiss Notifications";
            }
            {
              key = "<leader>.";
              mode = "n";
              lua = true;
              action = "function() Snacks.scratch() end";
              desc = "Toggle Scratch Buffer";
            }
            {
              key = "<leader>S";
              mode = "n";
              lua = true;
              action = "function() Snacks.scratch.select() end";
              desc = "Select Scratch Buffer";
            }

            # Zen mode
            {
              key = "<leader>uz";
              mode = "n";
              lua = true;
              action = "function() Snacks.zen() end";
              desc = "Toggle Zen Mode";
            }

            # Terminal
            {
              key = "<C-/>";
              mode = "t";
              lua = true;
              action = "function() Snacks.terminal() end";
              desc = "Toggle Terminal";
            }
          ];
        };
      };
    };
  };
}
