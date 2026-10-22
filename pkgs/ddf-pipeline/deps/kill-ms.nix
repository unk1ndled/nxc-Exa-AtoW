{
  lib,
  python3,
  ddfacet,
  mpiSupport ? false,
  mpi ? null,
}:
python3.pkgs.buildPythonApplication rec {
  pname = "kill-ms";
  version = "3.2.2-NH";
  pyproject = true;

  src = fetchGit {
    url = "git@gricad-gitlab.univ-grenoble-alpes.fr:exa-atow/killMS.git";
    rev = "c8f178848e6effaede8bdfb97dfe7c3303dedaeb";
    ref = "HackathonRennes";
  };

  dontUseCmakeConfigure = true;

  build-system = with python3.pkgs; [
    cmake
    cython_0
    numpy
    ninja
    pathspec
    pyproject-metadata
    scikit-build-core
    pybind11 # >= 2.2.2
  ];

  # Include system MPI for native compilation if support is enabled
  buildInputs = lib.optionals mpiSupport [
    mpi
  ];

  dependencies =
    with python3.pkgs;
    [
      ddfacet
      toml
      cython_0
    ]
    ++ lib.optionals mpiSupport [
      mpi4py
      fasteners
    ];

  optional-dependencies = with python3.pkgs; {
    mpi-support = [
      mpi4py
      fasteners

    ];
  };

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail \
        '"numpy>=1.15.1,<=1.22.0"' \
        '"numpy>=1.15.1"'
    substituteInPlace pyproject.toml \
      --replace-fail \
        'cython<=0.29.30' \
        'cython'
  '';

  pythonImportsCheck = [
    "killMS"
  ];

  meta = {
    description = "A Wirtinger-based direction-dependent radio interferometric calibration package";
    homepage = "https://pypi.org/project/killMS";
    license = lib.licenses.gpl2Only;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "kill-ms";
  };
}
