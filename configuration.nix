{ config, pkgs, pkgs-stable, lib, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # --- Nix Settings ---
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
  boot.loader.grub.useOSProber = true;
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
  ];

  # --- System Optimization & Networking ---
  zramSwap.enable = true;
  networking.hostName = "quietcraft";
  networking.networkmanager.enable = true;

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

  # --- DConf (required by GTK/GNOME apps to persist settings) ---
  programs.dconf.enable = true;
  programs.dconf.profiles.user.databases = [{
    settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
  }];
  
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
  
  nixpkgs.config.allowUnfree = true;

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
    brave
    blender
    godot
    kitty
    nautilus
    gnome-text-editor
    file-roller
    zed-editor
    mpv
    imv
    sassc
    loupe
    proton-vpn
    evince
    qbittorrent
    telegram-desktop
    vesktop
      
    # CLI / Essentials
    cava
    efibootmgr
    brightnessctl
    cliphist
    wl-clipboard
    libsecret
    xdg-user-dirs
    ffmpeg
    ffmpegthumbnailer
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
    kdePackages.qtmultimedia 
    wget
    grim
    slurp 
    swappy
    ddcutil
    lm_sensors
    fish
    aubio
    libqalculate
    ninja
    app2unit
      
    # Gaming
    pkgs-stable.heroic
    mangohud
    faugus-launcher
    protonplus
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
    tela-icon-theme

    # Development
    rustup
    zls

    # Mist DE Dependencies
     # wayland
     # wayland-protocols
    #  libxkbcommon
     # freetype
     # harfbuzz
     # pixman
    #  fontconfig
    #  basu
     # river
     # gcc
    #  gnumake
     # cmake
     # pkg-config
     # zig
     
    (python3.withPackages (ps: with ps; [
      openai
      requests
      pip
      numpy
    ]))

    # Flake Inputs
    inputs.nix-packages.packages.${pkgs.stdenv.hostPlatform.system}.rootapp
    inputs.nix-packages.packages.${pkgs.stdenv.hostPlatform.system}.opencode-desktop
    inputs.zen-browser-flake.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
   # inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default
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

  # --- Environment Variables ---
  environment.sessionVariables = {
    SDL_VIDEODRIVER = "wayland";
    NIXOS_OZONE_WL = "1";
    WLR_DRM_NO_ATOMIC = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    QT_QPA_PLATFORMTHEME = "gtk3";
  };

  system.stateVersion = "26.05";
}
