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
    trusted-users = [ "root" "ackerman" ];
    substituters = lib.mkForce [
      "https://mirror.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://cache.nixos.org/"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  # --- Bootloader & Kernel ---
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.useOSProber = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
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
  services.displayManager.ly.enable = false;
  # programs.mango.enable = true; # Mangowm

  # Native nixpkgs module (was programs.noctalia-greeter flake module)
  services.displayManager.noctalia-greeter = {
    enable = true;
    settings = {
      cursor.size = 24;
      keyboard.layout = "us";
    };
    cursorTheme = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
    };
  };

  # Umbriel compositor with portal - binary via cachix (follows nixpkgs)
  programs.umbriel = {
    enable = true;
    portalPackage = inputs.xdg-desktop-portal-umbriel.packages.${pkgs.stdenv.hostPlatform.system}.default;
  };
  
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
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    LIBVA_DRIVER_NAME = "radeonsi";
  };

  environment.systemPackages = with pkgs; [
    brightnessctl
    efibootmgr 
    adw-gtk3
    bibata-cursors
    nwg-look
    kdePackages.qt6ct
    kdePackages.qtstyleplugin-kvantum
    # Flake Inputs - system-wide
    inputs.nix-packages.packages.${pkgs.stdenv.hostPlatform.system}.opencode-desktop
    inputs.nix-packages.packages.${pkgs.stdenv.hostPlatform.system}.zen-browser
    noctalia
    inputs.nix-packages.packages.${pkgs.stdenv.hostPlatform.system}.helium
    inputs.nix-packages.packages.${pkgs.stdenv.hostPlatform.system}.protonplus
    inputs.nix-packages.packages.${pkgs.stdenv.hostPlatform.system}.mixtapes

    # GUI Apps
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
    # wlr = { # Mango wlr - Umbriel is the way
    #   enable = true;
    #   settings.screencast = {
    #     chooser_type = "simple";
    #     chooser_cmd = "slurp -f 'Monitor: %o' -or";
    #   };
    # };
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      # pkgs.xdg-desktop-portal-wlr  # Mango wlr - Umbriel is the way
    ];
    config = {
      common = {
        default = [ "gtk" ];
      };
      
      # mango = { # Mango - Umbriel is the way
      #   default = [ "gtk" ];
      #   "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
      #   "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
      # };
    };
  };

  system.stateVersion = "26.11";
}
