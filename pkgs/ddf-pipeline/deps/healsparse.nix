{
  lib,
  python3,
  fetchPypi,
  hpgeom,
}:
python3.pkgs.buildPythonPackage rec {
  pname = "healsparse";
  version = "1.9.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-6Dx2lz2kZzQr0iioCQftcC/b41Z9MgwhCTXnsr/xBhc=";
  };

  postPatch = ''
    sed -i '/setuptools_scm_git_archive/d' pyproject.toml
    sed -i '/setuptools_scm_git_archive/d' requirements.txt
  '';

  build-system = with python3.pkgs; [
    setuptools
    setuptools-scm
    wheel
  ];

  dependencies = with python3.pkgs; [
    hpgeom
    astropy
    numpy
  ];

  doCheck = false;

  pythonImportsCheck = [ "healsparse" ];

  meta = {
    description = "Sparse healpix maps and geometry library";
    homepage = "https://pypi.org/project/healsparse";
    license = lib.licenses.bsd3;
  };
}
