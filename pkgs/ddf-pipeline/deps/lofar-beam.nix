{
  lib,
  python3,
  fetchFromGitHub,
  cmake,
  casacore,
  boost,
}:
let
  boostWithPython = boost.override {
    enablePython = true;
    python = python3;
  };
in

python3.pkgs.buildPythonPackage rec {
  pname = "lofar-beam";
  version = "0-unstable-2025-12-28";
  pyproject = false;

  src = fetchFromGitHub {
    owner = "cyriltasse";
    repo = "LOFARBeam";
    rev = "0b012e633025bd9bd4314fc6d84acae40679153c";
    hash = "sha256-4GrBrkgSPUi77J01jX0f2+A458sVlUMTxP/XY1rfPW4=";
  };

  nativeBuildInputs = [ cmake ];

  buildInputs = [
    casacore
    python3
    boostWithPython
  ];

  # Force C++17 at the compiler level
  env.NIX_CFLAGS_COMPILE = "-std=c++17";

  cmakeFlags = [
    "-DPYTHON_EXECUTABLE=${python3.interpreter}"
    "-DPYTHON_INSTALL_DIR=${placeholder "out"}/${python3.sitePackages}"

    # more language version stuff
    "-DCMAKE_CXX_STANDARD=17"
    "-DCMAKE_CXX_STANDARD_REQUIRED=ON"

    "-DCASACORE_ROOT_DIR=${casacore}"
    "-Wno-dev"
  ];

  meta = {
    description = "LOFAR station response library";
    homepage = "https://github.com/cyriltasse/LOFARBeam";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.all;
  };
}
