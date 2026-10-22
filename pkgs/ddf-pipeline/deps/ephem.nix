{
  lib,
  python3,
  fetchPypi,
}:

python3.pkgs.buildPythonApplication rec {
  pname = "ephem";
  version = "4.2";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-PE/WT0U+j0DPhiQgpw2pWnG2SHrOdejgz4XXNwfbYGU=";
  };

  build-system = [
    python3.pkgs.setuptools
    python3.pkgs.wheel
  ];

  pythonImportsCheck = [
    "ephem"
  ];

  meta = {
    description = "Compute positions of the planets and stars";
    homepage = "https://pypi.org/project/ephem/";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "ephem";
  };
}
