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
  version = "0.2.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-16XFncG1nDQPFBXpbi7Qeqxtx/pxyVNr/J/QNlrHTe0=";
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
