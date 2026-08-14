{ config, pkgs, pkgs-stable, lib, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # --- Nix Settings ---
  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    max-jobs = "auto";
    substituters = lib.mkForce [
      "https://mirror.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://cache.nixos.org/"
      "https://noctalia.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  # --- Bootloader & Kernel ---
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.useOSProber = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "quiet"
    "splash"
    "boot.shell_on_fail"
    "udev.log_priority=3"
    "rd.systemd.show_status=auto"
    "amd_pstate=active"
    "amdgpu.gpu_recovery=1"
  ];

  # --- System Optimization & Networking ---
  zramSwap.enable = true;
  networking.hostName = "quietcraft";
  networking.networkmanager.enable = true;

  # --- Automatic Garbage Collection ---
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # --- Limit GRUB menu entries ---
  boot.loader.grub.configurationLimit = 10;

  # --- Environment Variables ---
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    LIBVA_DRIVER_NAME = "radeonsi";
  };

  # --- Time & Locale ---
  time.timeZone = "Asia/Dhaka";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # --- Hardware & Graphics ---
  hardware.enableAllFirmware = true;
  hardware.cpu.amd.updateMicrocode = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      mesa.opencl
    ];
  };

  # --- Display Manager & Desktop ---
  services.displayManager.ly.enable = true;
  programs.mango.enable = true;
  
  # --- User Account ---
  users.users.ackerman = {
    isNormalUser = true;
    description = "Quietcraft";
    extraGroups = [ "networkmanager" "wheel" "video" "input" "gamemode" ];
    shell = pkgs.zsh;
  };
  
  # --- Programs & Gaming ---
  programs.zsh.enable = true;
  programs.starship.enable = true;
  programs.git.enable = true;
  programs.steam.enable = true;
  programs.gamemode.enable = true;
  programs.dconf.enable = true;

  # --- Neovim with LazyVim ---
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;

    configure = let
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
    in {
      packages.myVimPackage = with pkgs.vimPlugins; {
        start = [ lazy-nvim ];
        opt = [ ];
      };
      customLuaRC = ''
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
            { import = "extras" },
            { import = "plugins" },
            { "mason-org/mason.nvim", enabled = false },
            { "mason-org/mason-lspconfig.nvim", enabled = false },
            { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = {} } },
          },
        })
        -- Nix-compiled treesitter parsers (searchable via runtimepath)
        vim.opt.runtimepath:append("${grammarsPath}")
      '';
    };
  };

  # --- NIX LD ---
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib 
    zlib
    fuse3
    icu
    nss
    openssl
    curl
    expat
    libxkbcommon
    vulkan-loader
    glib       
    libxml2        
    libgcc        
  ];

  # --- System Packages ---
  environment.systemPackages = with pkgs; [
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
   #telegram-desktop
   #vesktop
      
    # CLI / Essentials
    cava
    efibootmgr
    brightnessctl
    cliphist
    wl-clipboard
    libsecret
    xdg-user-dirs
    ffmpeg-full
    ffmpegthumbnailer
    libheif
    libva-utils

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
    vulkan-loader
    
    # Theming
    adw-gtk3
    bibata-cursors
    nwg-look
    kdePackages.qt6ct
    kdePackages.qtstyleplugin-kvantum
    papirus-icon-theme

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

  # --- Fonts ---
  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      lohit-fonts.bengali
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      font-awesome
      material-symbols
      nerd-fonts.jetbrains-mono
    ];
    fontconfig.defaultFonts = {
      serif = [ "Noto Serif" "Noto Serif Bengali" ];
      sansSerif = [ "Noto Sans" "Noto Sans Bengali" ];
      monospace = [ "JetBrainsMono Nerd Font" "Noto Sans Mono" ];
    };
  };

  # --- Services ---
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.dbus.enable = true;
  services.power-profiles-daemon.enable = true;
  services.gnome.gnome-keyring.enable = true;
  services.gnome.localsearch.enable = false;
  systemd.user.services.speech-dispatcher = { enable = false; aliases = []; wantedBy = []; };
   
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # --- Audio (Pipewire) ---
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  # --- Portals & Mime Types ---
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    wlr = {
      enable = true;
      settings.screencast = {
        chooser_type = "simple";
        chooser_cmd = "slurp -f 'Monitor: %o' -or";
      };
    };
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-wlr 
    ];
    config = {
      common = {
        default = [ "gtk" ];
      };
      
      mango = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
      };
    };
  };

  xdg.mime.defaultApplications = {
    "inode/directory" = [ "org.gnome.Nautilus.desktop" "nemo.desktop" ];
  };

  system.stateVersion = "26.11";
}
