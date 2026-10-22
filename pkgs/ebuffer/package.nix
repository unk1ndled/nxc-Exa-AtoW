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
  version = "0.1.5";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-Dv13IF5O0V4aHUGPJ+5I6hSMeOYDEbDU1w6o3ytwDTc=";
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
