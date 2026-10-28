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
  version = "2.0.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-a5RbXpQzObavrJKwvXZaxk/iiDLURG0hCrzgOszRU+4=";
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
