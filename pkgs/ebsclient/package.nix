{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  requests,
  ebcommon,
  remotemanager,
}:

buildPythonPackage rec {
  pname = "ebsclient";
  version = "0.1.1";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-7pfYe4KRp1ZAc5DqvJwW50JOHI7xvbcNoqmXXaxinhI=";
  };

  build-system = [ setuptools ];

  dependencies = [
    requests
    ebcommon
    remotemanager
  ];

  # tests require live ebservice/ebuffer servers
  doCheck = false;

  meta = {
    description = "Python client for ebuffer, ebservice and ebmessage";
    license = lib.licenses.mit;
  };
}
