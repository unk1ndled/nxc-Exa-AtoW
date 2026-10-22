{
  lib,
  python3,
  fetchPypi,
  ephem
}:

python3.pkgs.buildPythonApplication rec {
  pname = "pyephem";
  version = "9.99";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-cINtfqt4JO8fz+ECt1HZeADUoP9oNtLllN2xwR5gix8=";
  };

  build-system = [
    python3.pkgs.setuptools
    python3.pkgs.wheel
  ];

  propagatedBuildInputs = [
    ephem
  ];

  pythonImportsCheck = [
    "ephem"
  ];

  meta = {
    description = "Empty package that depends on \"ephem";
    homepage = "https://pypi.org/project/pyephem/";
    license = lib.licenses.lgpl2Only;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "pyephem";
  };
}
