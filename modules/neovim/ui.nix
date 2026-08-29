_: {
  flake.modules.homeManager.neovim = {
    programs.nvf = {
      settings = {
        vim = {
          statusline = {
            lualine = {
              enable = true;
              integrations.breadcrumbs = {
                nvim-navic.enable = true;
                navbuddy.enable = true;
                location = "winbar";
              };
            };
          };
          tabline = {
            nvimBufferline = {
              enable = true;
            };
          };
          ui = {
            borders.enable = true;
            colorizer.enable = true;
            noice.enable = true;
          };
        };
      };
    };
  };
}
