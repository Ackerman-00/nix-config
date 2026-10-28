{
  pkgs,
  lib,
}:

let
  pname = "openchamber";
  version = "2.5.3";

  url = "https://github.com/openchamber/openchamber/releases/download/v${version}/OpenChamber-${version}-linux-x86_64.AppImage";

  src = pkgs.fetchurl {
    inherit url;
    hash = "sha256-wDSorfUq9bxQ+Z3OmU1wFZdBB00MQmb0VrcPWbyB3jI=";
  };

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

    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
      $out/opt/openchamber/openchamber \
      $out/opt/openchamber/chrome_crashpad_handler

    mkdir -p $out/share/icons
    cp -r $out/opt/openchamber/usr/share/icons/. $out/share/icons/

    ln -s $out/opt/openchamber/openchamber $out/bin/openchamber

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${rpath}
      --add-flags "--no-sandbox"
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto}}"
    )
  '';

  doInstallCheck = true;

  installCheckPhase = ''
    test -x $out/bin/openchamber
    test -f $out/share/applications/openchamber.desktop
    test -f $out/share/icons/hicolor/512x512/apps/openchamber.png
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
