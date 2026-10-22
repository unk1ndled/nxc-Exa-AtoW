{
  lib,
  makeWrapper,
  stdenv,
  ebRepoSrc,
  cwl-utils,
  requests,
  ebcommon,
  python,
}:
let
  pythonEnv = python.withPackages (ps: [
    ebcommon
    requests
    cwl-utils
  ]);
in
stdenv.mkDerivation rec {
  pname = "ebuffer-tests";
  version = "0.1.0";
  src = "${ebRepoSrc}/tests";

  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/tests
    cp -rL . $out/lib/tests/

    mkdir -p $out/bin
    for script in \
      appowner/mservice_developer.py \
      appowner/runtime_maintainer.py \
      client/testMain.py
    do
      bin=$out/bin/$(basename "''${script%.py}")
      makeWrapper ${pythonEnv}/bin/python "$bin" \
        --add-flags "$out/lib/tests/$script" \
        --chdir "$out/lib/tests/$(dirname $script)"
    done

    runHook postInstall
  '';

}
