{
  pkgs,
  lib,
  omnirushFeed,
}:

let
  pname = "omnirush";

  feed = builtins.readFile omnirushFeed;
  lines = lib.splitString "\n" feed;

  field =
    name:
    lib.removePrefix name (
      lib.findFirst (l: lib.hasPrefix name l) (throw "omnirush: no `${name}` in the update feed") lines
    );

  version = field "version: ";

  debIndex =
    lib.findFirst
      (i: builtins.match "  - url: .*linux-amd64-.*\\.deb" (builtins.elemAt lines i) != null)
      (throw "omnirush: the update feed lists no linux-amd64 .deb")
      (lib.range 0 (builtins.length lines - 1));

  debName = lib.removePrefix "  - url: " (builtins.elemAt lines debIndex);

  debHash = lib.removePrefix "    sha512: " (
    lib.findFirst (
      l: lib.hasPrefix "    sha512: " l
    ) (throw "omnirush: no sha512 for ${debName} in the update feed") (lib.drop (debIndex + 1) lines)
  );

  hash = "sha512-${debHash}";

  url = "https://github.com/omnirush-ai/omnirush-gui/releases/download/v${version}/${debName}";

  src = pkgs.fetchurl {
    inherit url hash;
  };

  runtimeDeps = with pkgs; [
    stdenv.cc.cc.lib
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libappindicator-gtk3
    libdrm
    libgbm
    libGL
    libnotify
    libpulseaudio
    libsecret
    libuuid
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    libxscrnsaver
    libxtst
    nspr
    nss
    pango
    udev
    wayland
  ];

  rpath = lib.makeLibraryPath runtimeDeps;
in
pkgs.stdenv.mkDerivation {
  inherit pname version src;

  dontConfigure = true;
  dontBuild = true;
  dontPatchELF = true;

  nativeBuildInputs = with pkgs; [
    dpkg
    patchelf
    makeWrapper
    copyDesktopItems
    (wrapGAppsHook3.override { makeWrapper = makeShellWrapper; })
  ];

  buildInputs = with pkgs; [
    glib
    gsettings-desktop-schemas
    gtk3
    adwaita-icon-theme
  ];

  unpackPhase = ''
    dpkg -x $src .
  '';

  desktopItems = [
    (pkgs.makeDesktopItem {
      name = "omnirush";
      desktopName = "OmniRush";
      exec = "omnirush %U";
      icon = "omnirush";
      startupWMClass = "ai.omnirush";
      comment = "OmniRush.ai desktop shell";
      categories = [ "Development" ];
      mimeTypes = [ "x-scheme-handler/omnirush" ];
    })
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/opt/omnirush $out/share
    cp -r opt/omnirush/. $out/opt/omnirush/
    cp -r usr/share/icons $out/share/

    find $out/opt/omnirush -type f -perm -u+x -print0 | while IFS= read -r -d "" f; do
      if patchelf --print-interpreter "$f" >/dev/null 2>&1; then
        patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$f"
      fi
    done

    ln -s $out/opt/omnirush/omnirush $out/bin/omnirush

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${rpath}
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto}}"
    )
  '';

  doInstallCheck = true;

  installCheckPhase = ''
    test -x $out/bin/omnirush
    ls $out/opt/omnirush/resources/sidecars/opencode*-x86_64-unknown-linux-gnu
    test -f $out/share/applications/omnirush.desktop
    test -f $out/share/icons/hicolor/512x512/apps/omnirush.png
  '';

  passthru = {
    inherit version debName;
  };

  meta = {
    homepage = "https://omnirush.ai";
    description = "OmniRush.ai desktop shell";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "omnirush";
  };
}
