{
  lib,
  python3,
  fetchPypi,
  extension-helpers,

}:

python3.pkgs.buildPythonApplication rec {
  pname = "regions";
  version = "0.5";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-rImHWsi1IncyKlTpUtO9fR9IUQqvNCNU4H3wBZlkWa4=";
  };

  build-system = with python3.pkgs; [
    cython
    extension-helpers
    oldest-supported-numpy
    numpy
    setuptools
    setuptools-scm
  ];

  dependencies = with python3.pkgs; [
    astropy
    numpy
  ];

  optional-dependencies = with python3.pkgs; {
    all = [
      matplotlib
      shapely
    ];
    docs = [
      regions
      sphinx-astropy
      tomli
    ];
    test = [
      pytest-arraydiff
      pytest-astropy
    ];
  };

  postPatch = ''
    substituteInPlace  pyproject.toml \
    --replace "cython==0.29.22" "cython>=0.29.22"
  '';

  pythonImportsCheck = [
    "regions"
  ];

  meta = {
    description = "An Astropy coordinated package for region handling";
    homepage = "https://pypi.org/project/regions/";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "regions";
  };
}
