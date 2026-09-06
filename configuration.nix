{ pkgs, lib, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  custom = inputs.nix-packages.packages.${system};
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  # --- Nix ---
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
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # --- Boot ---
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
    kernelPackages = pkgs.linuxPackages_latest;
    initrd.kernelModules = [ "amdgpu" ];
    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
      "amd_pstate=active"
      "amdgpu.gpu_recovery=1"
    ];
  };

  # --- System ---
  zramSwap.enable = true;
  networking = {
    hostName = "quietcraft";
    networkmanager.enable = true;
  };
  time.timeZone = "Asia/Dhaka";

  # --- Locale ---
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
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
  };

  # --- Hardware & Graphics ---
  hardware = {
    enableAllFirmware = true;
    cpu.amd.updateMicrocode = true;
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        mesa.opencl
      ];
    };
  };

  # --- Display ---
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

  programs.umbriel.enable = true;

  # --- User ---
  users.users.ackerman = {
    isNormalUser = true;
    description = "Quietcraft";
    extraGroups = [ "networkmanager" "wheel" "video" "input" "gamemode" ];
    shell = pkgs.zsh;
  };

  # --- Programs ---
  programs = {
    zsh.enable = true;
    starship.enable = true;
    git.enable = true;
    steam.enable = true;
    gamemode.enable = true;
    dconf.enable = true;
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
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
    };
  };

  # --- Environment ---
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    LIBVA_DRIVER_NAME = "radeonsi";
  };

  environment.systemPackages = with pkgs; [
    # Custom flake packages
    custom.opencode-desktop
    custom.zen-browser
    custom.helium
    custom.mixtapes

    # Desktop shell (native nixpkgs)
    noctalia

    # Theming
    adw-gtk3
    bibata-cursors
    kdePackages.qt6ct
    kdePackages.qtstyleplugin-kvantum
    nwg-look

    # System utils
    brightnessctl
    efibootmgr

    # GUI apps
    blender
    evince
    file-roller
    gnome-text-editor
    godot
    imv
    kitty
    loupe
    mpv
    nautilus
    proton-vpn
    qbittorrent
    sassc
    telegram-desktop
    vesktop
    zed-editor

    # CLI / essentials
    btop
    cava
    cliphist
    eza
    fastfetch
    ffmpeg-full
    ffmpegthumbnailer
    fzf
    gpu-screen-recorder
    grim
    libheif
    libsecret
    libva-utils
    p7zip
    rar
    ripgrep
    slurp
    swappy
    unzip
    wget
    wl-clipboard
    xdg-user-dirs
    zip

    # Codecs (GStreamer framework)
    gst_all_1.gst-libav
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-ugly

    # Gaming
    faugus-launcher
    heroic
    mangohud
    protonplus
    protontricks
    vulkan-tools

    # Development
    fd
    gcc
    lazygit
    lua-language-server
    marksman
    nil
    nixfmt
    prettier
    prettierd
    rustup
    stylua
    tree-sitter
    zls

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
  services = {
    gvfs.enable = true;
    udisks2.enable = true;
    dbus.enable = true;
    power-profiles-daemon.enable = true;
    gnome.gnome-keyring.enable = true;
    gnome.localsearch.enable = false;
    xserver.xkb = {
      layout = "us";
      variant = "";
    };
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;
    };
  };
  security.rtkit.enable = true;
  systemd.user.services.speech-dispatcher = { enable = false; aliases = [ ]; wantedBy = [ ]; };

  # --- Portals ---
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];
  };

  system.stateVersion = "26.11";
}
