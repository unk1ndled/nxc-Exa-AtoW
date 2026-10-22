{
  lib,
  python3,
  fetchPypi,
}:

python3.pkgs.buildPythonApplication rec {
  pname = "astlib";
  version = "0.12.1";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-y6JvHBF3/xWPrFAya64Vu7ZiXoCUa2mx5EWGLcjec6g=";
  };

  build-system = [
    python3.pkgs.setuptools
    python3.pkgs.wheel
  ];

  dependencies = with python3.pkgs; [
    astropy
    matplotlib
    numpy
    scipy
  ];
  
  pythonImportsCheck = [
    "astLib"
  ];
  
  meta = {
    description = "A set of python modules for producing simple plots, statistics, common calculations, coordinate conversions, and manipulating FITS images with World Coordinate System (WCS) information";
    homepage = "https://pypi.org/project/astLib/";
    license = with lib.licenses; [ lgpl21Only lgpl2Only ];
    maintainers = with lib.maintainers; [ ];
    mainProgram = "astlib";
  };
}
