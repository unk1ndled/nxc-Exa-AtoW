{
  lib,
  python3,
  fetchPypi,
}:
python3.pkgs.buildPythonPackage rec {
  pname = "hpgeom";
  version = "1.2.2";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-ASIpu5hOptv5rWz1s9dFhQjtM5H6q0Td6urmO8EXANk=";
  };

  build-system = with python3.pkgs; [
    setuptools
    setuptools-scm
    wheel
  ];

  postPatch = ''
    sed -i '/setuptools_scm_git_archive/d' pyproject.toml
    sed -i '/setuptools_scm_git_archive/d' requirements.txt
  '';

  dependencies = with python3.pkgs; [
    oldest-supported-numpy
    numpy
  ];

  doCheck = false;

  pythonImportsCheck = [ "hpgeom" ];

  meta = {
    description = "HEALPix pixel lookup and geometry routines with numpy";
    homepage = "https://pypi.org/project/hpgeom";
    license = with lib.licenses; [
      gpl3Only
      gpl3Plus
    ];
  };
}
