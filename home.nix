{ config, pkgs, lib, inputs, ... }:

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

  # Nix-compiled treesitter parsers.
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

  # --- Environment Variables ---
  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    LIBVA_DRIVER_NAME = "radeonsi";
  };

  # --- PATH additions ---
  home.sessionPath = [
    "${config.home.homeDirectory}/.cargo/bin"  # rustup proxies
  ];

  # --- User Packages ---
  home.packages = with pkgs; [
    # GUI Apps
   #brave
    blender
    godot
    kitty
    nautilus
    gnome-text-editor
    file-roller
    mpv
    imv
    sassc
    loupe
    proton-vpn
    evince
    qbittorrent
    telegram-desktop
    vesktop
    zed-editor
      
    # CLI / Essentials
    cava
    cliphist
    wl-clipboard
    libsecret
    xdg-user-dirs
    ffmpeg-full
    ffmpegthumbnailer
    libheif
    libva-utils
    opencode
    
    # System-wide codecs (GStreamer framework)
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav
    p7zip
    unzip
    zip
    rar
    fzf
    eza
    fastfetch
    ripgrep
    btop
    gpu-screen-recorder
    wget
    grim
    slurp 
    swappy
      
    # Gaming
    gamemode
    heroic
    mangohud
    faugus-launcher
    protontricks
    vulkan-tools
    
    # Theming
    adw-gtk3
    bibata-cursors
    nwg-look
    kdePackages.qt6ct
    kdePackages.qtstyleplugin-kvantum

    # Development
    rustup
    zls
    lazygit
    fd
    tree-sitter
    lua-language-server
    stylua
    nil
    nixfmt
    marksman
    prettier
    prettierd
    gcc

    (python3.withPackages (ps: with ps; [
      openai
      requests
      pip
      numpy
    ]))

    # Flake Inputs
   #inputs.nix-packages.packages.${pkgs.stdenv.hostPlatform.system}.rootapp
    inputs.nix-packages.packages.${pkgs.stdenv.hostPlatform.system}.opencode-desktop
    inputs.nix-packages.packages.${pkgs.stdenv.hostPlatform.system}.zen-browser
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
   #inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.nix-packages.packages.${pkgs.stdenv.hostPlatform.system}.helium
    inputs.nix-packages.packages.${pkgs.stdenv.hostPlatform.system}.protonplus
  ];

  # --- Neovim with LazyVim ---
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
      -- Nix-compiled treesitter parsers (searchable via runtimepath)
      vim.opt.runtimepath:append("${grammarsPath}")
    '';
  };
}
