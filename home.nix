{ config, pkgs, lib, ... }:

let
  # Plugins
  plugins = with pkgs.vimPlugins; [
    LazyVim
    base16-nvim
    blink-cmp
    bufferline-nvim
    cmp-buffer
    cmp-nvim-lsp
    cmp-path
    conform-nvim
    dressing-nvim
    flash-nvim
    friendly-snippets
    fzf-lua
    gitsigns-nvim
    grug-far-nvim
    indent-blankline-nvim
    lazydev-nvim
    lualine-nvim
    neo-tree-nvim
    noice-nvim
    no-clown-fiesta-nvim
    nui-nvim
    nvim-dap
    nvim-dap-ui
    nvim-lint
    nvim-lspconfig
    nvim-notify
    nvim-snippets
    nvim-spectre
    nvim-treesitter
    nvim-treesitter-textobjects
    nvim-ts-autotag
    persistence-nvim
    plenary-nvim
    render-markdown-nvim
    snacks-nvim
    telescope-nvim
    telescope-fzf-native-nvim
    todo-comments-nvim
    tokyonight-nvim
    trouble-nvim
    ts-comments-nvim
    which-key-nvim
    aerial-nvim
    rustaceanvim
  ];

  # Helpers
  mkEntryFromDrv = drv:
    if lib.isDerivation drv then
      { name = lib.getName drv; path = drv; }
    else
      drv;

  # Mini Modules
  miniModules = builtins.map
    (m: { name = m; path = pkgs.vimPlugins.mini-nvim; })
    [ "mini.ai" "mini.bufremove" "mini.comment" "mini.icons" "mini.indentscope" "mini.pairs" "mini.surround" ];

  # Treesitter
  treesitterGrammars = (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: with p; [
    rust
    bash
    c
    cpp
    comment
    css
    dockerfile
    gitcommit
    gitignore
    html
    javascript
    json
    lua
    make
    markdown
    markdown_inline
    nix
    python
    query
    regex
    sql
    toml
    tsx
    typescript
    vim
    vimdoc
    yaml
    zig
  ])).dependencies;

  # Grammars Path
  grammarsPath = pkgs.symlinkJoin {
    name = "nvim-treesitter-parsers";
    paths = treesitterGrammars;
  };

  # Lazy Path
  lazyPath = pkgs.linkFarm "lazy-plugins" (builtins.map mkEntryFromDrv plugins ++ miniModules);
in
{
  # Home Version
  home.stateVersion = "26.11";

  # Session Path
  home.sessionPath = [
    "${config.home.homeDirectory}/.cargo/bin"
  ];

  # Home Packages
  home.packages = with pkgs; [
    lua-language-server
    marksman
    nil
    prettier
    prettierd
    stylua
    tree-sitter
    zls
  ];

  # Neovim
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;

    plugins = with pkgs.vimPlugins; [ lazy-nvim ];

    initLua = ''
      vim.g.mapleader = " "
      vim.g.maplocalleader = " "

      -- Remember theme choice across restarts (must sit BEFORE lazy starts,
      -- so the very first theme apply is saved too)
      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function()
          local f = io.open(vim.fn.stdpath("config") .. "/theme.txt", "w")
          if f then
            f:write(vim.g.colors_name or "")
            f:close()
          end
        end,
      })

      -- No swap files, ever (undo history + sessions already guard work,
      -- swap only pops scary E325 boxes for beginners)
      vim.opt.swapfile = false

      require("lazy").setup({
        defaults = { lazy = true },
        dev = {
          path = "${lazyPath}",
          patterns = { "" },
          fallback = true,
        },
        spec = {
          { "LazyVim/LazyVim",
            import = "lazyvim.plugins",
            opts = {
              -- Last picked theme wins (saved to theme.txt on every switch).
              -- Plain string would forget your pick on restart.
              colorscheme = function()
                local path = vim.fn.stdpath("config") .. "/theme.txt"
                local f = io.open(path, "r")
                local name = f and f:read("*l") or nil
                if f then f:close() end
                if name == "matugen" then
                  -- Wallpaper theme: a lua module, not a colorscheme file
                  local ok, m = pcall(require, "matugen")
                  if ok and m then
                    pcall(m.setup)
                    vim.g.colors_name = "matugen"
                    return
                  end
                end
                if not (name and name ~= "" and pcall(vim.cmd.colorscheme, name)) then
                  vim.cmd.colorscheme("no-clown-fiesta")
                end
              end,
            },
          },
          -- Needed by the wallpaper theme module above (loads eagerly, tiny)
          { "RRethy/base16-nvim", lazy = false },
          { "aktersnurra/no-clown-fiesta.nvim", lazy = false, priority = 1000, opts = {} },
          -- Old theme, kept loaded so :colorscheme Tab offers it too
          { "folke/tokyonight.nvim", lazy = false, priority = 1000, opts = {} },
          { "mason-org/mason.nvim", enabled = false },
          { "mason-org/mason-lspconfig.nvim", enabled = false },
          { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = {} } },
          -- Book reading: pretty markdown inside the buffer (headings, code, lists)
          { "MeanderingProgrammer/render-markdown.nvim",
            ft = { "markdown" },
            opts = {
              code = { sign = false, width = "block", right_pad = 1 },
              heading = { sign = false, icons = {} },
              checkbox = { enabled = false },
            },
            config = function(_, opts)
              require("render-markdown").setup(opts)
            end,
          },
          -- Book reading: chapter list on the side
          { "stevearc/aerial.nvim",
            opts = {},
            keys = {
              { "<leader>o", "<cmd>AerialToggle<cr>", desc = "Outline (book chapters)" },
              { "]o", "<cmd>AerialNext<cr>", desc = "Next chapter" },
              { "[o", "<cmd>AerialPrev<cr>", desc = "Prev chapter" },
            },
            config = function(_, opts)
              require("aerial").setup(opts)
            end,
          },
        },
      })
      vim.opt.runtimepath:append("${grammarsPath}")

      -- Book reading: visual theme list with live preview (no Tab guessing)
      vim.keymap.set("n", "<leader>uC", function() Snacks.picker.colorschemes() end, { desc = "Colorschemes + preview" })

      -- Wallpaper theme (Noctalia/matugen): run :Matugen to use + remember it.
      -- Do NOT hand-edit lua/matugen.lua, your wallpaper tool rewrites it.
      vim.api.nvim_create_user_command("Matugen", function()
        require("matugen").setup()
        vim.g.colors_name = "matugen"
        local f = io.open(vim.fn.stdpath("config") .. "/theme.txt", "w")
        if f then
          f:write("matugen")
          f:close()
        end
        print("matugen theme on (saved)")
      end, { desc = "Wallpaper theme" })

      -- Book mode: normal 1-to-last line numbers + calm reading in markdown.
      -- (LazyVim uses relative numbers everywhere, so at the last line the
      -- gutter reads 500-to-1. This keeps plain 1, 2, 3 ... in .md files.)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function()
          vim.opt_local.number = true
          vim.opt_local.relativenumber = false
          vim.opt_local.wrap = true
          vim.opt_local.linebreak = true
          vim.opt_local.breakindent = true
          vim.opt_local.spell = true
          vim.opt_local.spelllang = { "en" }
          vim.opt_local.conceallevel = 2
        end,
      })
    '';
  };
}
