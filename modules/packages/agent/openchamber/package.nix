# OpenChamber desktop client, vendored in-tree (official AppImage).
#
# Upstream ships Linux only as an AppImage and publishes no hash manifest,
# so version + URL + hash are literals here (unlike the feed-pinned
# opencode/concat packages). Bump procedure: update the three literals
# below, then rebuild. Prefetch a new hash with:
#   nix store prefetch-file --json <url>
{
  pkgs,
  lib,
}:

let
  pname = "openchamber";
  version = "2.1.0";

  url = "https://github.com/openchamber/openchamber/releases/download/v${version}/OpenChamber-${version}-linux-x86_64.AppImage";

  src = pkgs.fetchurl {
    inherit url;
    hash = "sha256-q08g/HwXzLy+cgz8u7q9C1ksGdjn6+BmPXyz+RiggvI=";
  };

  # Unpack the AppImage at build time (extractType2 is deprecated upstream).
  extracted = pkgs.appimageTools.extract { inherit pname version src; };

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
    glib
    gtk3
    libdrm
    libgbm
    libGL
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    pango
    udev
  ];

  rpath = lib.makeLibraryPath runtimeDeps;
in
pkgs.stdenv.mkDerivation {
  inherit pname version;
  src = extracted;

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontPatchELF = true;

  nativeBuildInputs = with pkgs; [
    patchelf
    makeWrapper
    copyDesktopItems
    # Use shell wrapper so gappsWrapperArgs can evaluate ${NIXOS_OZONE_WL}
    (wrapGAppsHook3.override { makeWrapper = makeShellWrapper; })
  ];

  buildInputs = with pkgs; [
    glib
    gsettings-desktop-schemas
    gtk3
    adwaita-icon-theme
  ];

  desktopItems = [
    (pkgs.makeDesktopItem {
      name = "openchamber";
      desktopName = "OpenChamber";
      exec = "openchamber %U";
      icon = "openchamber";
      startupWMClass = "openchamber";
      comment = "Agentic development environment";
      categories = [ "Development" ];
    })
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/opt/openchamber

    cp -r $src/. $out/opt/openchamber/
    chmod u+w $out/opt/openchamber/openchamber $out/opt/openchamber/chrome_crashpad_handler

    # The bundled Electron was built for FHS distros and expects
    # /lib64/ld-linux; repoint at the Nix dynamic linker.
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
      $out/opt/openchamber/openchamber \
      $out/opt/openchamber/chrome_crashpad_handler

    # Upstream AppImage icon for the desktop entry.
    mkdir -p $out/share/icons/hicolor/scalable/apps
    cp $out/opt/openchamber/openchamber.svg $out/share/icons/hicolor/scalable/apps/openchamber.svg

    # Wrapper: link the bundled binary; wrapGAppsHook3 (via preFixup
    # gappsWrapperArgs below) turns it into a shell wrapper with the rpath
    # and native Wayland when the session asks for it.
    ln -s $out/opt/openchamber/openchamber $out/bin/openchamber

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${rpath}
      # Upstream AppImage runs with --no-sandbox; keep it (NixOS chromium
      # sandbox needs unprivileged user namespaces).
      --add-flags "--no-sandbox"
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto}}"
    )
  '';

  doInstallCheck = true;

  installCheckPhase = ''
    test -x $out/bin/openchamber
    test -f $out/share/applications/openchamber.desktop
  '';

  passthru = {
    inherit
      url
      version
      ;
  };

  meta = {
    homepage = "https://openchamber.dev";
    description = "Agentic development environment";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "openchamber";
  };
}
