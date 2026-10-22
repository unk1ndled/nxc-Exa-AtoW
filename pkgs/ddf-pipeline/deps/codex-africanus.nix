{
  lib,
  python3,
  fetchPypi,
}:

python3.pkgs.buildPythonPackage rec {
  pname = "codex-africanus";
  version = "0.3.5";
  pyproject = true;

  src = fetchPypi {
    inherit pname;
    inherit version;
    hash = "sha256-BIfZgKCFOGqcby7vYh7btZ+UaWSSexoEE4ysShqCLqA=";
  };

  build-system = [
    python3.pkgs.setuptools
  ];

  dependencies = with python3.pkgs; [
    appdirs
    decorator
    numba
    dask
    numpy
  ];

  optional-dependencies = with python3.pkgs; {
    astropy = [
      astropy
    ];
    complete = [
      astropy
      dask
      ducc0
      jax
      jaxlib
      python-casacore
      scipy
    ];
    complete-cuda = [
      astropy
      cupy
      dask
      ducc0
      jax
      jaxlib
      jinja2
      python-casacore
      scipy
    ];
    cuda = [
      cupy
      jinja2
    ];
    dask = [
      dask
    ];
    dev = [
      pre-commit
      ruff
      tbump
    ];
    doc = [
      numpydoc
      pydata-sphinx-theme
      pygments
      ruff
      sphinx
      sphinx-copybutton
    ];
    ducc0 = [
      ducc0
    ];
    jax = [
      jax
      jaxlib
    ];
    python-casacore = [
      python-casacore
    ];
    scipy = [
      scipy
    ];
    testing = [
      flaky
      pytest
    ];
  };

  pythonImportsCheck = [
    "africanus"
  ];

  meta = {
    description = "Radio Astronomy Building Blocks";
    homepage = "https://pypi.org/project/codex-africanus";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "codex-africanus";
  };
}
