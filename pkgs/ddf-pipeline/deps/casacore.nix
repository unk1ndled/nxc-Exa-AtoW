{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  gfortran,
  flex,
  bison,
  boost,
  blas,
  lapack,
  cfitsio,
  wcslib,
  fftw,
  fftwFloat,
  readline,
  gsl,
  python3,
}:
let
  boostWithPython = boost.override {
    enablePython = true;
    python = python3;
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "casacore";
  version = "3.8.0";

  src = fetchFromGitHub {
    owner = "casacore";
    repo = "casacore";
    rev = "v${finalAttrs.version}";
    hash = "sha256-NOxuHMCuHGk9XuWXMwQTN6kOFDI0QuHMgfNRDdlPw44=";
  };

  nativeBuildInputs = [
    cmake
    gfortran
    flex
    bison
  ];

  buildInputs = [
    blas
    lapack
    cfitsio
    wcslib
    fftw
    fftwFloat
    readline
    gsl
    python3 
    python3.pkgs.numpy
    boostWithPython
  ];

  enableParallelBuilding = true;

  strictDeps = true;

  cmakeFlags = [
    (lib.cmakeBool "ENABLE_SHARED" (!stdenv.hostPlatform.isStatic))
    (lib.cmakeBool "BUILD_PYTHON3" true)
  ];

  meta = {
    homepage = "https://casacore.github.io/casacore/";
    changelog = "https://github.com/casacore/casacore/blob/master/CHANGES.md";
    description = "Suite of C++ libraries for radio astronomy data processing";
    maintainers = with lib.maintainers; [  ];
    license = lib.licenses.lgpl2Only;
    platforms = lib.platforms.all;
  };
})
