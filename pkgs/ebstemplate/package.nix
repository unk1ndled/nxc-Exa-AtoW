{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  requests,
  ebcommon,
  remotemanager,
  ebsclient,
}:

buildPythonPackage rec {
  pname = "ebstemplate";
  version = "0.1.1";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-iCvkfv0ruP4I9rR094c4QfNRKH7iK4dydiFtacM8rrA=";
  };

  build-system = [ setuptools ];

  dependencies = [
    requests
    ebcommon
    remotemanager
    # ebsclient is an implicit runtime dependency (not listed in requires_dist
    # but the package imports from it directly)
    ebsclient
  ];

  # tests require live HPC / ebservice infrastructure
  doCheck = false;

  meta = {
    description = "HPC job scheduler templates built on top of ebsclient";
    license = lib.licenses.mit;
  };
}
