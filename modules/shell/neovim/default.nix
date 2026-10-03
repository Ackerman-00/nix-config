# Neovim (LazyVim):
{
  config,
  pkgs,
  lib,
  ...
}:

let
  # Plugins
  plugins = with pkgs.vimPlugins; [
    LazyVim
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
    neotest
    neotest-python
    noice-nvim
    nui-nvim
    nvim-dap
    nvim-dap-python
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
    snacks-nvim
    telescope-nvim
    telescope-fzf-native-nvim
    todo-comments-nvim
    tokyonight-nvim
    trouble-nvim
    ts-comments-nvim
    venv-selector-nvim
    which-key-nvim
    aerial-nvim
    rustaceanvim
  ];

  # Helpers
  mkEntryFromDrv =
    drv:
    if lib.isDerivation drv then
      {
        name = lib.getName drv;
        path = drv;
      }
    else
      drv;

  # Mini Modules
  miniModules =
    builtins.map
      (m: {
        name = m;
        path = pkgs.vimPlugins.mini-nvim;
      })
      [
        "mini.ai"
        "mini.bufremove"
        "mini.comment"
        "mini.icons"
        "mini.indentscope"
        "mini.pairs"
        "mini.surround"
      ];

  # Treesitter (python extra needs ninja + rst)
  treesitterGrammars =
    (pkgs.vimPlugins.nvim-treesitter.withPlugins (
      p: with p; [
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
        ninja
        nix
        python
        query
        regex
        rst
        sql
        toml
        tsx
        typescript
        vim
        vimdoc
        yaml
        zig
      ]
    )).dependencies;

  # Grammars Path
  grammarsPath = pkgs.symlinkJoin {
    name = "nvim-treesitter-parsers";
    paths = treesitterGrammars;
  };

  # Lazy Path
  lazyPath = pkgs.linkFarm "lazy-plugins" (builtins.map mkEntryFromDrv plugins ++ miniModules);

  nvim = config.home-manager.users.ackerman.programs.neovim.finalPackage;
in
{
  home-manager.users.ackerman = {
    home.packages = with pkgs; [
      lua-language-server
      marksman
      nil
      prettier
      prettierd
      stylua
      tree-sitter
      zls
      # Python (LazyVim lang.python, mason off so binaries come from Nix).
      # Default LSP: basedpyright (drop-in pyright + inlay hints/semantic tokens).
      basedpyright
      pyright
      ruff
      ty
      python3Packages.debugpy
    ];

    # Launcher for Open With: kitty provides the terminal.
    xdg.desktopEntries.nvim = {
      name = "Neovim";
      genericName = "Text Editor";
      comment = "Edit text files";
      exec = "${lib.getExe pkgs.kitty} ${lib.getExe nvim} %F";
      icon = "${pkgs.neovim}/share/icons/hicolor/128x128/apps/nvim.png";
      terminal = false;
      startupNotify = false;
      categories = [
        "Utility"
        "TextEditor"
      ];
      mimeType = [
        "text/plain"
        "text/markdown"
        "text/html"
        "text/css"
        "text/csv"
        "text/javascript"
        "text/xml"
        "application/json"
        "application/x-shellscript"
        "application/x-yaml"
        "text/x-python"
        "text/x-lua"
        "text/x-chdr"
        "text/x-csrc"
        "text/x-c++hdr"
        "text/x-c++src"
        "text/x-java"
        "text/x-go"
        "text/x-sh"
      ];
    };

    programs.neovim = {
      enable = true;
      defaultEditor = true;
      vimAlias = true;
      viAlias = true;

      plugins = with pkgs.vimPlugins; [ lazy-nvim ];

      initLua = ''
        vim.g.mapleader = " "
        vim.g.maplocalleader = " "

        -- LazyVim Python (2026): basedpyright + ruff. Set to "ty" for Astral ty.
        vim.g.lazyvim_python_lsp = "basedpyright"
        vim.g.lazyvim_python_ruff = "ruff"

        require("lazy").setup({
          defaults = { lazy = true },
          dev = {
            path = "${lazyPath}",
            patterns = { "" },
            fallback = true,
          },
          spec = {
            { "LazyVim/LazyVim", import = "lazyvim.plugins" },
            { import = "lazyvim.plugins.extras.lang.python" },
            { "mason-org/mason.nvim", enabled = false },
            { "mason-org/mason-lspconfig.nvim", enabled = false },
            { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = {} } },
          },
        })
        vim.opt.runtimepath:append("${grammarsPath}")

        -- IDE terminal: Ctrl+` toggles Snacks terminal (2026 default backend).
        -- Keep LazyVim defaults (<leader>ft, <C-/>) and add VSCode-style <C-`>.
        vim.keymap.set({ "n", "t" }, "<C-`>", function()
          Snacks.terminal.toggle()
        end, { desc = "Terminal (Root Dir)" })

        -- Autosave every 10s, always (after lazy.setup so LazyVim can't override updatetime).
        vim.opt.updatetime = 10000
        vim.opt.autowrite = true
        vim.opt.autowriteall = true
        vim.fn.timer_start(10000, function()
          vim.schedule(function()
            pcall(vim.cmd, "silent! wall")
          end)
        end, { ["repeat"] = -1 })
        vim.api.nvim_create_autocmd({ "FocusLost", "BufLeave", "VimLeavePre" }, {
          group = vim.api.nvim_create_augroup("AutoSave10s", { clear = true }),
          callback = function()
            pcall(vim.cmd, "silent! wall")
          end,
        })
      '';
    };
  };
}
