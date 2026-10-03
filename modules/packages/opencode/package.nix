# OpenCode desktop client, vendored in-tree (official prebuilt .deb).
# Version, URL and sha512 come from the `opencode-feed` flake input, so
# flake.lock is the only pin and `nix flake update` is the whole procedure.
{
  pkgs,
  lib,
  opencodeFeed,
}:

let
  pname = "opencode-desktop";
  artifact = "opencode-desktop-linux-amd64.deb";

  feed = builtins.readFile opencodeFeed;
  feedLines = lib.splitString "\n" feed;
  lastLine = builtins.length feedLines - 1;
  lineAt = i: lib.trim (builtins.elemAt feedLines i);

  # `key: value`, accepting either a top-level field (`version: 1.2.3`) or a
  # list item (`- url: https://...`). `start` bounds the search so every field
  # is read from the artifact's own entry rather than a previous one.
  field =
    start: key:
    let
      found = lib.findFirst (i: lib.hasInfix "${key}: " (lineAt i)) null (lib.range start lastLine);
    in
    if found == null then
      throw "opencode feed: no `${key}:` entry for ${artifact}"
    else
      lib.last (lib.splitString "${key}: " (lineAt found));

  # Index of our artifact among the feed's `files:` entries.
  entry = lib.findFirst (
    i: lib.hasInfix artifact (lineAt i)
  ) (throw "opencode feed: no `${artifact}` entry") (lib.range 0 lastLine);

  version = field 0 "version";
  hash = "sha512-${field entry "sha512"}";

  # Upstream owns the URL shape; only reject a parse that produced garbage.
  url =
    let
      raw = field entry "url";
    in
    if lib.hasPrefix "https://" raw then
      raw
    else
      throw "opencode feed: unexpected artifact URL `${raw}`";

  src = pkgs.fetchurl { inherit url hash; };

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
  inherit pname version src;

  dontConfigure = true;
  dontBuild = true;
  dontPatchELF = true;

  nativeBuildInputs = with pkgs; [
    dpkg
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

  unpackPhase = ''
    dpkg -x $src .
  '';

  desktopItems = [
    (pkgs.makeDesktopItem {
      # Match upstream filename so existing mimeapps mapping keeps working.
      name = "ai.opencode.desktop";
      desktopName = "OpenCode";
      exec = "opencode-desktop %U";
      icon = "ai.opencode.desktop";
      startupWMClass = "ai.opencode.desktop";
      comment = "Open source AI coding agent";
      categories = [ "Development" ];
      mimeTypes = [ "x-scheme-handler/opencode" ];
    })
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/opt/opencode-desktop

    cp -r opt/OpenCode/. $out/opt/opencode-desktop/

    # The bundled Electron was built for FHS distros and expects
    # /lib64/ld-linux; repoint at the Nix dynamic linker.
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
      $out/opt/opencode-desktop/ai.opencode.desktop \
      $out/opt/opencode-desktop/chrome_crashpad_handler

    # Upstream hicolor icons for the desktop entry.
    mkdir -p $out/share/icons
    cp -r usr/share/icons/. $out/share/icons/

    # Wrapper: link the bundled binary; wrapGAppsHook3 (via preFixup
    # gappsWrapperArgs below) turns it into a shell wrapper with the rpath
    # and native Wayland when the session asks for it.
    ln -s $out/opt/opencode-desktop/ai.opencode.desktop $out/bin/opencode-desktop

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
    test -x $out/bin/opencode-desktop
    test -f $out/share/applications/ai.opencode.desktop.desktop
  '';

  # The resolved pin, for inspection: nix eval .#packages.x86_64-linux.opencode-desktop.passthru
  passthru = {
    inherit
      url
      hash
      version
      ;
  };

  meta = {
    homepage = "https://opencode.ai";
    description = "AI coding agent desktop client";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "opencode-desktop";
    maintainers = [
      {
        name = "Ackerman-00";
        github = "Ackerman-00";
      }
    ];
  };
}
