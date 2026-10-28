{
  pkgs,
  lib,
  fetchurl,
}:

let
  pname = "craft-launcher";
  version = "0.9.0";

  url = "https://github.com/storytold/craft-launcher/releases/download/v${version}/artcraft-launcher-${version}-linux-x86_64.tar.gz";

  hash = "sha256-md5vDTANWi6Y4RcrVXpcfABnVIzMqRRukuSLkDPx8to=";

  src = fetchurl { inherit url hash; };

  runtimeDeps = with pkgs; [
    dbus
    libxkbcommon
    wayland
    libx11
    libxcursor
    libxi
    vulkan-loader
    libGL
  ];

  runtimeBins = [ pkgs.zenity ];
in
pkgs.stdenv.mkDerivation {
  inherit pname version src;

  dontConfigure = true;
  dontBuild = true;
  dontPatchELF = true;

  nativeBuildInputs = with pkgs; [
    patchelf
    makeWrapper
    copyDesktopItems
  ];

  sourceRoot = "artcraft-launcher-${version}-linux-x86_64";

  desktopItems = [
    (pkgs.makeDesktopItem {
      name = "ai.storyteller.artcraft-launcher";
      desktopName = "ArtCraft Launcher";
      exec = "artcraft-launcher";
      icon = "ai.storyteller.artcraft-launcher";
      startupWMClass = "artcraft-launcher";
      comment = "Install, update and launch the Craft App Suite";
      categories = [
        "Utility"
        "PackageManager"
      ];
    })
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/icons $out/share/metainfo
    cp bin/artcraft-launcher $out/bin/
    cp -r share/icons/. $out/share/icons/
    cp share/metainfo/*.xml $out/share/metainfo/

    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
      $out/bin/artcraft-launcher

    runHook postInstall
  '';

  preFixup = ''
    wrapProgram $out/bin/artcraft-launcher \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeDeps} \
      --prefix PATH : ${lib.makeBinPath runtimeBins}
  '';

  doInstallCheck = true;

  installCheckPhase = ''
    test -x $out/bin/artcraft-launcher
    test -f $out/share/applications/ai.storyteller.artcraft-launcher.desktop
  '';

  passthru = {
    inherit url hash version;
  };

  meta = {
    homepage = "https://github.com/storytold/craft-launcher";
    description = "Install, update and launch the Craft App Suite";
    license = lib.licenses.OR [
      lib.licenses.asl20
      lib.licenses.mit
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "artcraft-launcher";
  };
}
