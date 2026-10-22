pfinal: pprev:
let
  noCheck =
    pkg:
    pkg.overridePythonAttrs (_: {
      doCheck = false;
    });
in
{
  astropy = noCheck pprev.astropy;
  filelock = noCheck pprev.filelock;
  pytest-xdist = noCheck pprev.pytest-xdist;
  scipy = noCheck pprev.scipy;
  dask = noCheck pprev.dask;
  fsspec = noCheck pprev.fsspec;
  uvloop = noCheck pprev.uvloop;
  virtualenv = noCheck pprev.virtualenv;
  hypothesis = noCheck pprev.hypothesis;
  networkx = noCheck pprev.networkx;
  poetry-core = noCheck pprev.poetry-core;
  requests = noCheck pprev.requests;
  sqlalchemy = noCheck pprev.sqlalchemy;
  h2 = noCheck pprev.h2;
  cycler = noCheck pprev.cycler;
  eventlet = noCheck pprev.eventlet;
  aiohttp = noCheck pprev.aiohttp;

  yarl = pprev.yarl.overridePythonAttrs (old: {
    # yarl-1.9.4/pyproject.toml --
    # requires = [
    #   ...
    #   "tomli; python_version < '3.11'",
    # ]
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pprev.tomli ];
    doCheck = false;
  });
}
