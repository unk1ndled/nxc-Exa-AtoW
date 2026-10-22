{
  lib,
  python3,
  python-casacore,
  regions,
  sharedarray,
  cmake,
  ninja,
  codex-africanus,
  skyproj,

  pyephem,
  pyfftw,
  lofar-beam,

  # mpi flags
  mpiSupport ? false,
  mpi ? null,
}:
python3.pkgs.buildPythonPackage rec {
  pname = "dd-facet";
  version = "0.8.0.0-NH";
  pyproject = true;

  # Since CMAKE lists resides within an inner source folder, we need to disable the default CMake configuration
  # leaving cmake invocation entirely to scikit-build-core which will correctly use cmake.source-dir = "DDFacet" from the toml.
  dontUseCmakeConfigure = true;

  src = fetchGit {
    url = "git@gricad-gitlab.univ-grenoble-alpes.fr:exa-atow/DDFacet.git";
    rev = "675ce535422c70bb1499d00a2437657a8bfcb9ff";
    ref = "HackathonRennes";
  };

  nativeBuildInputs = [
    cmake
    ninja
    python3.pkgs.pythonRelaxDepsHook
  ];

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace '"numpy >= 1.15.1, <= 1.22.4; python_version >= '"'"'3.10'"'"'"' '"numpy >= 1.15.1"' \
      --replace '"numpy >= 1.15.1, <= 1.22.4; python_version >= '"'"'3.8'"'"' and python_version < '"'"'3.10'"'"'"' '"numpy >= 1.15.1"' \
      --replace '"numpy >= 1.15.1, <= 1.26; python_version >= '"'"'3.10'"'"'"' '"numpy >= 1.15.1"' \
      --replace "'cython<=0.29.30'" "'cython'" \
      --replace '"Cython >= 0.25.2, <= 0.29.30"' '"cython"'
  '';

  build-system = with python3.pkgs; [
    cython_0
    numpy
    pybind11
    scikit-build-core
    pyproject-metadata
    pathspec
    setuptools
  ];

  # Include the system MPI library if mpiSupport is enabled
  buildInputs = lib.optionals mpiSupport [
    mpi
  ];

  dependencies =
    with python3.pkgs;
    [
      astropy # >= 3.0
      codex-africanus
      configparser
      cython_0
      dask
      deap
      ipdb
      matplotlib
      numexpr
      numpy
      pandas
      polygon3
      prettytable
      psutil
      ptyprocess
      py-cpuinfo
      pybind11
      pyephem
      pyfftw
      pylru
      python-casacore
      pywavelets
      regions
      ruamel-yaml
      scipy
      sharedarray
      six
      skyproj
      tables
      toml
      tqdm
      lofar-beam
    ]
    ++ lib.optionals mpiSupport [
      mpi4py
      fasteners
    ];

  optional-dependencies = with python3.pkgs; {
    alternate-data-backends = [
      dask-ms
      xarray
    ];
    dft-support = [
      montblanc
    ];
    fits-beam-support = [
      meqtrees-cattery
    ];
    kms-support = [
      bdsf
    ];
    moresane-support = [
      pymoresane
    ];
    mpi-support = [
      mpi4py
      fasteners
    ];
    testing-requirements = [
      nose
      owlcat
      pynose
    ];
  };

  pythonRelaxDeps = [
    "numexpr"
    "matplotlib"
    "pybind11"
    "configparser"
    "pandas"
    "dask"
    "pywavelets"
    "tqdm"
  ];

  pythonImportsCheck = [
    "DDFacet"
  ];

  meta = {
    description = "Facet-based radio astronomy continuum imager";
    homepage = "https://pypi.org/project/DDFacet/";
    license = lib.licenses.gpl2Only;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "dd-facet";
  };
}
