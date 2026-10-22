{
  lib,
  python3,
  fetchPypi,
}:

python3.pkgs.buildPythonApplication rec {
  pname = "extension-helpers";
  version = "1.4.0";
  pyproject = true;

  src = fetchPypi {
    pname = "extension_helpers";
    inherit version;
    hash = "sha256-eNBBhfGW4+C8X9hBjOKYsBTEb3rGCfaowQv3DoyXgyQ=";
  };

  build-system = [
    python3.pkgs.setuptools
    python3.pkgs.setuptools-scm
  ];

  dependencies = with python3.pkgs; [
    setuptools
    tomli
  ];

  optional-dependencies = with python3.pkgs; {
    docs = [
      sphinx
      sphinx-automodapi
    ];
    test = [
      build
      cython
      pytest
      pytest-cov
      wheel
    ];
  };

  pythonImportsCheck = [
    "extension_helpers"
  ];

  meta = {
    description = "Utilities for building and installing packages with compiled extensions";
    homepage = "https://pypi.org/project/extension-helpers";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "extension-helpers";
  };
}
