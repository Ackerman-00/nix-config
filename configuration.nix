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
  # (user apps moved to home.nix; kept here: udev-rule tools & sudo-used tools)
  environment.systemPackages = with pkgs; [
    brightnessctl   # ships udev rules - must be system-wide
    efibootmgr      # used with sudo (not in user profile PATH)
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

  system.stateVersion = "26.11";
}

