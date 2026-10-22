{
  fetchPypi,
  cmake,
  casacore,
  wcslib,
  cfitsio,
  lib,
  blas,
  lapack,
  ncurses,
  readline,
  flex,
  bison,
  fftw,
  fftwFloat,
  boost,
  gsl,
  python3,
}:

let
  boostWithPython = boost.override {
    enablePython = true;
    python = python3;
  };
in

python3.pkgs.buildPythonPackage rec {
  pname = "python-casacore";
  version = "3.6.1";
  pyproject = true;

  src = fetchPypi {
    pname = "python_casacore";
    inherit version;
    hash = "sha256-3cGsGGtuomNqxqJxVo3lL0hev28h2dAKQhb8OhZRu4E=";
  };

  build-system = with python3.pkgs; [
    scikit-build-core
    pathspec
    setuptools-scm
    pyproject-metadata
    ninja
  ];

  nativeBuildInputs = [
    cmake
  ];

  dontUseCmakeConfigure = true;

  buildInputs = [
    casacore
    wcslib
    cfitsio
    blas
    lapack
    ncurses
    readline
    flex
    bison
    fftw
    fftwFloat
    boostWithPython
    gsl
  ];

  cmakeFlags = [
    "-DCASACORE_ROOT_DIR=${casacore}"
  ];

  dependencies = with python3.pkgs; [
    numpy
    six
  ];

  pythonImportsCheck = [
    "casacore"
    "pyrap"
  ];

  meta = {
    description = "A wrapper around CASACORE, the radio astronomy library";
    homepage = "https://pypi.org/project/python-casacore/";
    license = lib.licenses.lgpl3;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "python-casacore";
  };
}
