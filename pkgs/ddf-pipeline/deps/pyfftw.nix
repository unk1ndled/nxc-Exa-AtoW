{
  lib,
  python3,
  fetchPypi,
  fftw
}:

python3.pkgs.buildPythonApplication rec {
  pname = "pyfftw";
  version = "0.15.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-Lxa5hUpAyP3RCqWAOyTdxqtJ+c1Vnb1/B+fWGqIFwco=";
  };

  build-system = [
    python3.pkgs.cython
    python3.pkgs.numpy
    python3.pkgs.setuptools
    python3.pkgs.wheel
  ];

  dependencies = with python3.pkgs; [
    numpy
    setuptools
    fftw
  ];

  optional-dependencies = with python3.pkgs; {
    dask = [
      dask
      numpy
    ];
    scipy = [
      scipy
    ];
  };
  pythonImportsCheck = [
    "pyfftw"
  ];

  meta = {
    description = "A pythonic wrapper around FFTW, the FFT library, presenting a unified interface for all the supported transforms";
    homepage = "https://pypi.org/project/pyFFTW/";
    license = lib.licenses.bsd2;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "pyfftw";
  };
}
