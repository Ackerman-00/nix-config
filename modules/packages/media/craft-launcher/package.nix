# Craft launcher
{
  pkgs,
  lib,
  fetchurl,
  craftLauncherFeed,
}:

let
  feed = builtins.fromJSON (builtins.readFile craftLauncherFeed);

  assets = builtins.filter (a: builtins.match ".*linux-x86_64\\.tar\\.gz" a.name != null) feed.assets;

  asset =
    if assets == [ ] then
      throw "craft-launcher: the ${feed.tag_name} release has no linux-x86_64.tar.gz asset"
    else
      builtins.head assets;

  version = lib.removePrefix "v" feed.tag_name;

  url = asset.browser_download_url;

  hash =
    if asset ? digest && asset.digest != null && asset.digest != "" then
      asset.digest
    else
      throw "craft-launcher: the release asset ${asset.name} has no digest; the GitHub release API must answer with one";

  src = fetchurl { inherit url hash; };

  runtimeDeps = with pkgs; [
    libxkbcommon
    wayland
    libx11
    libxcursor
    libxi
    vulkan-loader
    libGL
  ];
in
pkgs.stdenv.mkDerivation {
  pname = "craft-launcher";
  inherit version src;

  dontConfigure = true;
  dontBuild = true;
  dontPatchELF = true;

  nativeBuildInputs = with pkgs; [
    patchelf
    makeWrapper
    copyDesktopItems
  ];

  sourceRoot = lib.removeSuffix ".tar.gz" asset.name;

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
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeDeps}
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
