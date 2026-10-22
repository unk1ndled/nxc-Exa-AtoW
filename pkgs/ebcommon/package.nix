{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  pydantic,
  requests,
}:

buildPythonPackage rec {
  pname = "ebcommon";
  version = "1.0.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-PKug9iU/o3klW/dDhgfrt5h6Vc9MmIKYVH7zkkoy7iI=";
  };

  build-system = [ setuptools ];

  dependencies = [
    pydantic
    requests
  ];

  meta = {
    description = "Ephemeral buffer service common model";
    license = lib.licenses.mit;
  };
}
