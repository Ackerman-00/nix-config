{
  pkgs,
  lib,
  hyperframesSrc,
}:
let
  upstream = "${hyperframesSrc}/skills";
  overrides = ./overrides;
  overrideNames = builtins.attrNames (
    lib.filterAttrs (_: e: e == "directory") (builtins.readDir overrides)
  );
in
pkgs.runCommand "hyperframes-skills"
  {
    meta = {
      description = "HyperFrames skills: upstream source plus the local adaptations";
      license = lib.licenses.asl20;
      platforms = [ "x86_64-linux" ];
    };
  }
  ''
    cp -r ${upstream} ./skills
    chmod -R u+w ./skills
    rm -f ./skills/python-encoding.test.mjs
    for n in ${toString overrideNames}; do
      if [ ! -d "./skills/$n" ]; then
        echo "hyperframes-skills: override '$n' has no upstream skill to adapt" >&2
        exit 1
      fi
      cp -r ${overrides}/$n/. "./skills/$n/"
    done
    find ./skills -name 'heygen*' -print -delete
    if find ./skills -name 'heygen*' -print -quit | grep -q .; then
      echo "hyperframes-skills: a HeyGen provider script survived the merge" >&2
      exit 1
    fi
    mkdir -p $out/skills
    cp -r ./skills/. $out/skills/
  ''
