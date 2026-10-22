{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  pyyaml,
  requests,
  typing-extensions,
}:

buildPythonPackage rec {
  pname = "remotemanager";
  version = "0.14.3";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-RtaAVNrpEOl0VvULQg08aBgbz6VtOOHiQmK5n3Q/0E0=";
  };

  build-system = [ setuptools ];

  dependencies = [
    pyyaml
    requests
    typing-extensions
  ];

  # avoid network-dependent tests
  doCheck = false;

  meta = {
    description = "Remote run management tool for HPC workflows";
    homepage = "https://gitlab.com/l_sim/remotemanager/";
    license = lib.licenses.mit;
  };
}
