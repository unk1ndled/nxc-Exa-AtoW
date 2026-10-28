{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  fastapi,
  pydantic,
  sqlalchemy,
  requests,
  sqlmodel,
  pyyaml,
}:

buildPythonPackage rec {
  pname = "ebuffer";
  version = "0.3.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-1j0ygbaptlouCJ8F5VMiZvYAhnLCvGJ1eb2aEK28Vl4=";
  };

  build-system = [ setuptools ];

  dependencies = [
    fastapi
    pydantic
    sqlalchemy
    requests
    sqlmodel
    pyyaml
  ];

  meta = {
    description = "Ephemeral buffer service";
    license = lib.licenses.mit;
  };
}
