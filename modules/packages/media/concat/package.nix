{
  pkgs,
  lib,
  concatManifest,
}:

let
  pname = "concat";

  manifest = builtins.fromJSON (builtins.readFile concatManifest);

  arch =
    {
      x86_64-linux = "x86_64";
      aarch64-linux = "aarch64";
    }
    .${pkgs.stdenv.hostPlatform.system}
      or (throw "concat: manifest has no entry for ${pkgs.stdenv.hostPlatform.system}");

  version = lib.removePrefix "v" manifest.version;

  entry =
    manifest.binaries.linux.${arch}.deb or (throw "concat: manifest has no linux/${arch} deb entry");

  url =
    if lib.hasPrefix "https://github.com/jub0t/Concat/releases/download/" entry.url then
      entry.url
    else
      throw "concat: unexpected artifact URL `${entry.url}`";

  src = pkgs.fetchurl {
    inherit url;
    inherit (entry) sha256;
  };

  runtimeDeps = with pkgs; [
    stdenv.cc.cc.lib
    alsa-lib
    fontconfig
    freetype
    gtk3
    libglvnd
    libxkbcommon
    libGL
    vulkan-loader
    wayland
    libx11
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
      name = "concat";
      desktopName = "Concat";
      exec = "concat %U";
      icon = "concat";
      comment = "Video editor";
      categories = [
        "AudioVideo"
        "Video"
      ];
    })
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/opt/concat

    cp -r opt/concat/. $out/opt/concat/

    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
      $out/opt/concat/concat

    mkdir -p $out/share/icons
    cp -r usr/share/icons/. $out/share/icons/

    ln -s $out/opt/concat/concat $out/bin/concat

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${rpath}
    )
  '';

  doInstallCheck = true;

  installCheckPhase = ''
    test -x $out/bin/concat
    test -f $out/share/applications/concat.desktop
  '';

  passthru = {
    inherit
      url
      version
      ;
    hash = entry.sha256;
  };

  meta = {
    homepage = "https://github.com/jub0t/Concat";
    description = "Free and open source video editor";
    license = lib.licenses.agpl3Only;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = lib.platforms.linux;
    mainProgram = "concat";
  };
}
