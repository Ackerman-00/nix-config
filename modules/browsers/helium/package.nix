{
  pkgs,
  lib,
  fetchurl,
}:

let
  pname = "helium";
  version = "0.20.2.1";

  url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64_linux.tar.xz";

  hash = "sha256-upKssn7GzaNqi5SOIVQAmq7g1jMiKtJEviXnNqFD5vo=";

  src = fetchurl { inherit url hash; };

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
    libdrm
    libx11
    libGL
    libxkbcommon
    libxscrnsaver
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxshmfence
    libxtst
    libuuid
    libgbm
    nspr
    nss
    pango
    pipewire
    udev
    wayland
    libxcb
    zlib
    snappy
    libkrb5
    qt5.qtbase
    qt6.qtbase
    libpulseaudio
    libva
  ];

  rpath = lib.makeLibraryPath runtimeDeps;
in
pkgs.stdenv.mkDerivation {
  inherit pname version src;

  dontConfigure = true;
  dontBuild = true;
  dontPatchELF = true;

  nativeBuildInputs = with pkgs; [
    patchelf
    makeWrapper
    (wrapGAppsHook3.override { makeWrapper = makeShellWrapper; })
  ];

  buildInputs = with pkgs; [
    glib
    gsettings-desktop-schemas
    gtk3
    adwaita-icon-theme
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/opt/helium $out/share/applications $out/share/metainfo \
             $out/share/icons/hicolor/256x256/apps

    cp -r . $out/opt/helium/

    substituteInPlace $out/opt/helium/helium-wrapper \
      --replace-fail '#!/bin/sh' '#!${pkgs.stdenv.shell}' \
      --replace-fail 'CHROME_VERSION_EXTRA="custom"' 'CHROME_VERSION_EXTRA="nixos"'

    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
      $out/opt/helium/helium $out/opt/helium/helium_crashpad_handler $out/opt/helium/chromedriver

    ln -s $out/opt/helium/helium-wrapper $out/bin/helium

    install -m 644 $out/opt/helium/helium.desktop $out/share/applications/
    rm $out/opt/helium/helium.desktop
    install -m 644 $out/opt/helium/product_logo_256.png \
      $out/share/icons/hicolor/256x256/apps/helium.png

    cat > $out/share/metainfo/net.imput.helium.metainfo.xml <<EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <component type="desktop-application">
      <id>net.imput.helium</id>
      <launchable type="desktop-id">helium.desktop</launchable>
      <metadata_license>CC0-1.0</metadata_license>
      <project_license>GPL-3.0-only</project_license>
      <name>Helium</name>
      <summary>Private, fast, and honest web browser</summary>
      <description>
        <p>Helium is a private, fast, and honest web browser based on Chromium.
        It prioritizes user privacy while maintaining excellent performance and
        a clean browsing experience.</p>
      </description>
      <url type="homepage">https://github.com/imputnet/helium-linux</url>
      <releases>
        <release version="${version}" />
      </releases>
      <developer id="net.imput">
        <name>imput</name>
      </developer>
    </component>
    EOF

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${rpath}
      --suffix PATH : ${lib.makeBinPath [ pkgs.xdg-utils ]}
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto}}"
    )
  '';

  doInstallCheck = true;

  installCheckPhase = ''
    $out/bin/helium --version
  '';

  passthru = {
    inherit
      url
      hash
      version
      ;
  };

  meta = {
    homepage = "https://github.com/imputnet/helium-linux";
    description = "Private, fast, and honest web browser based on Chromium";
    license = with lib.licenses; [
      gpl3Plus
      bsd3
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = lib.platforms.linux;
    mainProgram = "helium";
    maintainers = [
      {
        name = "Ackerman-00";
        github = "Ackerman-00";
      }
    ];
  };
}
