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
  version = "0.3.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-j7ZSDrpln/qeu1iNSrRz8ilyjFuaAzJWdSmeJxCnxtk=";
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
