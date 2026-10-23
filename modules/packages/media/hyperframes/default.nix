# HyperFrames
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.my.hyperframes;
  hf = import ./lib.nix;
  hm = inputs.home-manager.lib;
  skills = pkgs.callPackage ./skills.nix { hyperframesSrc = inputs.hyperframes-src; };
  cli = pkgs.writeShellApplication {
    name = "hyperframes";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      exec npx --yes hyperframes@${cfg.cliVersion} "$@"
    '';
  };
  # Python pin
  kokoroPython = pkgs.python313;
  kokoroPip = kokoroPython.pkgs.pip;
  pyTag = lib.concatStringsSep "." (lib.take 2 (lib.splitVersion kokoroPython.version));
  homeDir = config.users.users.ackerman.home;
  kokoroVenv = "${homeDir}/.local/share/hyperframes/kokoro-venv";
  zlibLib = lib.makeLibraryPath [ pkgs.zlib ];
  # libstdc++
  gccLib = lib.makeLibraryPath [ pkgs.gcc-unwrapped.lib ];
  soundfileVersion = "0.13.1";
in
{
  options.my.hyperframes = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "HyperFrames CLI, skills, local voice and transcription.";
    };

    cliVersion = lib.mkOption {
      type = lib.types.str;
      default = hf.npmLatest inputs.hyperframes-npm;
      description = "HyperFrames CLI version; `nh os switch --update` re-reads the npm feed.";
    };

    kokoroVersion = lib.mkOption {
      type = lib.types.str;
      default = hf.pypiLatest inputs.kokoro-pypi;
      description = "Kokoro version for local voiceover; `nh os switch --update` re-reads the PyPI feed.";
    };

    torchVersion = lib.mkOption {
      type = lib.types.str;
      default = hf.pypiLatest inputs.torch-pypi;
      description = ''
        torch version for the local MusicGen BGM fallback. The CPU wheel is
        installed: gfx908 has no ROCm build, so the CPU path is the only one.
      '';
    };

    transformersVersion = lib.mkOption {
      type = lib.types.str;
      default = hf.pypiLatest inputs.transformers-pypi;
      description = "transformers version for the local MusicGen BGM fallback.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.whisper-cpp ];

    my.python.packages = [ "soundfile" ];

    home-manager.users.ackerman.home = {
      file = {
        ".local/bin/hyperframes".source = "${cli}/bin/hyperframes";
      };

      sessionVariables = {
        HYPERFRAMES_PYTHON = "${kokoroVenv}/bin/python";
      };

      # hm-backup
      activation.hyperframes-skills = hm.hm.dag.entryAfter [ "writeBoundary" ] ''
        skills_src="${skills}/skills"
        skills_dst="${homeDir}/.agents/skills"
        skills_backup="${homeDir}/.local/state/hyperframes/skills"
        if [[ -v DRY_RUN ]]; then
          echo "hyperframes: would copy the skills into $skills_dst"
        else
          mkdir -p "$skills_dst" "$skills_backup"
          for src in "$skills_src"/*; do
            [[ -d "$src" ]] || continue
            name=''${src##*/}
            dst="$skills_dst/$name"
            if [[ -e "$dst" ]] && ! diff -rq "$src" "$dst" >/dev/null 2>&1; then
              stamp=$(date -u +%Y%m%dT%H%M%SZ)
              mkdir -p "$skills_backup/$name"
              cp -r "$dst" "$skills_backup/$name/$stamp"
              echo "hyperframes: kept the changed copy of $name in $skills_backup/$name/$stamp"
            fi
            rm -rf "$dst"
            cp -r "$src" "$dst"
          done
        fi
      '';

      activation.hyperframes-kokoro = hm.hm.dag.entryAfter [ "writeBoundary" ] ''
        # Activation PATH
        kokoro_version() {
          "${kokoroVenv}/bin/python" -c 'import importlib.metadata as m; print(m.version("kokoro-onnx"))' 2>/dev/null
        }
        kokoro_usable() {
          [ -x "${kokoroVenv}/bin/python" ] || return 1
          [ "$(kokoro_version)" = "${cfg.kokoroVersion}" ] || return 1
          "${kokoroVenv}/bin/python" -c 'import kokoro_onnx' >/dev/null 2>&1 || return 1
        }
        if ! kokoro_usable; then
          rm -rf "${kokoroVenv}"
          ${kokoroPython}/bin/python3 -m venv --copies --without-pip "${kokoroVenv}"
          # Wheel RPATH
          for p in "${kokoroVenv}/bin/python" "${kokoroVenv}/bin/python3" "${kokoroVenv}/bin/python${pyTag}"; do
            [ -f "$p" ] || continue
            ${pkgs.patchelf}/bin/patchelf --force-rpath \
              --set-rpath "$(${pkgs.patchelf}/bin/patchelf --print-rpath "$p"):${zlibLib}:${gccLib}" "$p"
          done
          ${kokoroPip}/bin/pip --python "${kokoroVenv}/bin/python" install --upgrade pip
          ${kokoroPip}/bin/pip --python "${kokoroVenv}/bin/python" \
            install "kokoro-onnx==${cfg.kokoroVersion}" "soundfile==${soundfileVersion}"
          "${kokoroVenv}/bin/python" -c 'import kokoro_onnx'
        fi
        musicgen_version() {
          "${kokoroVenv}/bin/python" -c 'import importlib.metadata as m; print(m.version("torch").split("+")[0], m.version("transformers"))' 2>/dev/null
        }
        if [ "$(musicgen_version || true)" != "${cfg.torchVersion} ${cfg.transformersVersion}" ]; then
          ${kokoroPip}/bin/pip --python "${kokoroVenv}/bin/python" \
            install "torch==${cfg.torchVersion}" --index-url https://download.pytorch.org/whl/cpu
          ${kokoroPip}/bin/pip --python "${kokoroVenv}/bin/python" \
            install "transformers==${cfg.transformersVersion}"
          "${kokoroVenv}/bin/python" -c 'import transformers, torch'
        fi
      '';
    };
  };
}
