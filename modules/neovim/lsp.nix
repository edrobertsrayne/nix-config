_: {
  flake.modules.homeManager.neovim = {
    programs.nvf = {
      settings = {
        vim = {
          lsp = {
            enable = true;
            formatOnSave = true;
            lightbulb.enable = true;
            lspkind.enable = true;
          };

          keymaps = [
            # === LSP (quick access) ===
            {
              key = "K";
              mode = "n";
              lua = true;
              action = "vim.lsp.buf.hover";
              desc = "Hover documentation";
            }
            {
              key = "gK";
              mode = "n";
              lua = true;
              action = "vim.lsp.buf.signature_help";
              desc = "Signature help";
            }
            {
              key = "gd";
              mode = "n";
              lua = true;
              action = "vim.lsp.buf.definition";
              desc = "Go to definition";
            }
            {
              key = "gD";
              mode = "n";
              lua = true;
              action = "vim.lsp.buf.declaration";
              desc = "Go to declaration";
            }
            {
              key = "gr";
              mode = "n";
              lua = true;
              action = "vim.lsp.buf.references";
              desc = "Go to references";
            }
            {
              key = "gI";
              mode = "n";
              lua = true;
              action = "vim.lsp.buf.implementation";
              desc = "Go to implementation";
            }
            {
              key = "gy";
              mode = "n";
              lua = true;
              action = "vim.lsp.buf.type_definition";
              desc = "Go to type definition";
            }

            # === Code/LSP ===
            {
              key = "<leader>ca";
              mode = "n";
              lua = true;
              action = "vim.lsp.buf.code_action";
              desc = "Code actions";
            }
            {
              key = "<leader>cr";
              mode = "n";
              lua = true;
              action = "vim.lsp.buf.rename";
              desc = "Rename symbol";
            }
            {
              key = "<leader>cf";
              mode = "n";
              lua = true;
              action = "vim.lsp.buf.format";
              desc = "Format code/buffer";
            }
            {
              key = "<leader>cD";
              mode = "n";
              lua = true;
              action = "vim.lsp.buf.declaration";
              desc = "Go to declaration";
            }
            {
              key = "<leader>ci";
              mode = "n";
              lua = true;
              action = "vim.lsp.buf.implementation";
              desc = "Go to implementation";
            }
            {
              key = "<leader>cy";
              mode = "n";
              lua = true;
              action = "vim.lsp.buf.type_definition";
              desc = "Go to type definition";
            }
            {
              key = "<leader>ch";
              mode = "n";
              lua = true;
              action = "vim.lsp.buf.hover";
              desc = "Hover documentation";
            }
            {
              key = "<leader>cd";
              mode = "n";
              lua = true;
              action = "vim.diagnostic.open_float";
              desc = "Line diagnostics";
            }

            # === Diagnostics ===
            {
              key = "]d";
              mode = "n";
              lua = true;
              action = "function() vim.diagnostic.goto_next() end";
              desc = "Next diagnostic";
            }
            {
              key = "[d";
              mode = "n";
              lua = true;
              action = "function() vim.diagnostic.goto_prev() end";
              desc = "Previous diagnostic";
            }
            {
              key = "]e";
              mode = "n";
              lua = true;
              action = "function() vim.diagnostic.goto_next({severity = vim.diagnostic.severity.ERROR}) end";
              desc = "Next error";
            }
            {
              key = "[e";
              mode = "n";
              lua = true;
              action = "function() vim.diagnostic.goto_prev({severity = vim.diagnostic.severity.ERROR}) end";
              desc = "Previous error";
            }
            {
              key = "]w";
              mode = "n";
              lua = true;
              action = "function() vim.diagnostic.goto_next({severity = vim.diagnostic.severity.WARN}) end";
              desc = "Next warning";
            }
            {
              key = "[w";
              mode = "n";
              lua = true;
              action = "function() vim.diagnostic.goto_prev({severity = vim.diagnostic.severity.WARN}) end";
              desc = "Previous warning";
            }

            # === LSP in insert mode ===
            {
              key = "<C-k>";
              mode = "i";
              lua = true;
              action = "vim.lsp.buf.signature_help";
              desc = "Signature help";
            }

            # === Code/LSP in visual mode ===
            {
              key = "<leader>ca";
              mode = "v";
              lua = true;
              action = "vim.lsp.buf.code_action";
              desc = "Code actions";
            }
            {
              key = "<leader>cf";
              mode = "v";
              lua = true;
              action = "vim.lsp.buf.format";
              desc = "Format selection";
            }
          ];
        };
      };
    };
  };
}
