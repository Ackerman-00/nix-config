{
  pkgs,
  lib,
  freebuffFeed,
}:

let
  pname = "freebuff";

  feed = builtins.readFile freebuffFeed;

  field =
    name:
    lib.findFirst (l: lib.hasPrefix name l) (throw "freebuff: no `${name}` in the update feed") (
      lib.splitString "\n" feed
    );

  version = lib.removePrefix "version: " (field "version: ");
  debPath = lib.removePrefix "path: " (field "path: ");
  hash = "sha512-" + lib.removePrefix "sha512: " (field "sha512: ");

  src = pkgs.fetchurl {
    url = "https://freebuff.com/api/desktop/updates/linux-x64-deb/${debPath}";
    inherit hash;
  };

  runtimeDeps = with pkgs; [
    stdenv.cc.cc.lib
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    curl
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
    zlib
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
      name = "freebuff";
      desktopName = "Freebuff";
      exec = "freebuff %U";
      icon = "freebuff";
      startupWMClass = "Freebuff";
      comment = "Freebuff Desktop";
      categories = [ "Development" ];
      mimeTypes = [ "x-scheme-handler/freebuff" ];
    })
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/opt/Freebuff $out/share
    cp -r opt/Freebuff/. $out/opt/Freebuff/
    cp -r usr/share/icons $out/share/

    find $out/opt/Freebuff -type f -perm -u+x -print0 | while IFS= read -r -d "" f; do
      if patchelf --print-interpreter "$f" >/dev/null 2>&1; then
        patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$f"
      fi
    done

    ln -s $out/opt/Freebuff/freebuff $out/bin/freebuff

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
    test -x $out/bin/freebuff
    test -x $out/opt/Freebuff/resources/bun/bun
    test -x $out/opt/Freebuff/resources/git/bin/git
    test -f $out/share/applications/freebuff.desktop
    test -f $out/share/icons/hicolor/512x512/apps/freebuff.png
  '';

  passthru = {
    inherit version debPath;
  };

  meta = {
    homepage = "https://freebuff.com";
    description = "Freebuff Desktop";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "freebuff";
  };
}
