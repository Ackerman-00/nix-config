{ config, pkgs, lib, ... }:

let
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
    noice-nvim
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
  mkEntryFromDrv = drv:
    if lib.isDerivation drv then
      { name = lib.getName drv; path = drv; }
    else
      drv;
  miniModules = builtins.map
    (m: { name = m; path = pkgs.vimPlugins.mini-nvim; })
    [ "mini.ai" "mini.bufremove" "mini.comment" "mini.icons" "mini.indentscope" "mini.pairs" "mini.surround" ];

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
  grammarsPath = pkgs.symlinkJoin {
    name = "nvim-treesitter-parsers";
    paths = treesitterGrammars;
  };
  lazyPath = pkgs.linkFarm "lazy-plugins" (builtins.map mkEntryFromDrv plugins ++ miniModules);
in
{
  home.stateVersion = "26.11";

  # --- PATH ---
  home.sessionPath = [
    "${config.home.homeDirectory}/.cargo/bin"
  ];

  # --- Neovim ---
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;

    plugins = with pkgs.vimPlugins; [ lazy-nvim ];

    initLua = ''
      vim.g.mapleader = " "
      vim.g.maplocalleader = " "

      require("lazy").setup({
        defaults = { lazy = true },
        dev = {
          path = "${lazyPath}",
          patterns = { "" },
          fallback = true,
        },
        spec = {
          { "LazyVim/LazyVim", import = "lazyvim.plugins" },
          { "mason-org/mason.nvim", enabled = false },
          { "mason-org/mason-lspconfig.nvim", enabled = false },
          { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = {} } },
        },
      })
      vim.opt.runtimepath:append("${grammarsPath}")
    '';
  };
}
