# Concat video editor, vendored in-tree (official prebuilt .deb).
# Version, URL and sha256 come from the `concat-manifest` flake input, so
# flake.lock is the only pin and `nix flake update` is the whole procedure.
# The .deb is unpacked (not AppImage/rpm): it lays out whole under
# /opt/concat with FFmpeg beside the binary, so dpkg plus an interpreter
# fix and a wrapper is the entire install.
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

  # The tag can carry a pre-release suffix; the version field is what
  # the bundles are named for.
  version = lib.removePrefix "v" manifest.version;

  entry =
    manifest.binaries.linux.${arch}.deb or (throw "concat: manifest has no linux/${arch} deb entry");

  # Upstream owns the URL shape; reject a parse that points anywhere else
  # rather than fetching something unexpected.
  url =
    if lib.hasPrefix "https://github.com/jub0t/Concat/releases/download/" entry.url then
      entry.url
    else
      throw "concat: unexpected artifact URL `${entry.url}`";

  src = pkgs.fetchurl {
    inherit url;
    inherit (entry) sha256;
  };

  # System libraries the bundle does NOT ship (upstream nfpm.yaml depends):
  # toolkit for file dialogs, fonts, xkb, GL, sound. Everything else
  # (FFmpeg, onnxruntime) rides in /opt/concat/lib by rpath.
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
    # Use shell wrapper so gappsWrapperArgs below can use shell expansions.
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

    # The bundled binary was built for FHS distros and expects
    # /lib64/ld-linux; repoint at the Nix dynamic linker.
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
      $out/opt/concat/concat

    # Upstream hicolor icon for the desktop entry.
    mkdir -p $out/share/icons
    cp -r usr/share/icons/. $out/share/icons/

    # Launcher on the path (upstream ships /usr/bin/concat doing the same).
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

  # The resolved pin, for inspection.
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
