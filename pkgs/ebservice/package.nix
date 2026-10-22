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
  ebuffer,
}:

buildPythonPackage rec {
  pname = "ebservice";
  version = "0.1.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-xB9SdTCWSvld2XX6kOdoKmBivMem7+Ofq7wTVj9akUs=";
  };

  build-system = [ setuptools ];

  dependencies = [
    fastapi
    pydantic
    sqlalchemy
    requests
    sqlmodel
    pyyaml
    ebuffer
  ];

  meta = {
    description = "Application microservice";
    license = lib.licenses.mit;
  };
}
