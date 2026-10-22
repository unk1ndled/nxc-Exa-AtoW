{
  lib,
  python3,
  fetchPypi,
  healsparse,
  hpgeom,
}:

python3.pkgs.buildPythonApplication rec {
  pname = "skyproj";
  version = "1.2.3";
  pyproject = true;

  src = fetchPypi {
    inherit pname;
    inherit version;
    hash = "sha256-AWevxcTqF6NfKip4u34rq9TqnJqnyYs8vV498LOOTZs=";
  };

  build-system = [
    python3.pkgs.setuptools
    python3.pkgs.setuptools-scm
    # broken asf python3.pkgs.setuptools-scm-git-archive
    python3.pkgs.wheel
  ];

  dependencies = with python3.pkgs; [
    astropy
    healsparse
    pyproj
    hpgeom
    matplotlib
    numpy
  ];
  postPatch = ''
    sed -i '/setuptools_scm_git_archive/d' pyproject.toml
    sed -i '/setuptools_scm_git_archive/d' requirements.txt
  '';
  pythonImportsCheck = [
    "skyproj"
  ];

  meta = {
    description = "Python tools for making sky projections and maps";
    homepage = "https://pypi.org/project/skyproj";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "skyproj";
  };
}
