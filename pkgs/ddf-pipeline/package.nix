{
  stdenv,
  lib,
  makeWrapper,
  python3,
  dysco,
  ddfacet,
  kill-ms,
  python-casacore,
  fetchurl,
  fetchzip,
  unzip,
  openmpi,
  ...
}:
let
  py = python3.withPackages (ps: [
    ddfacet
    kill-ms
    python-casacore
    ps.mpi4py
    ps.future
    ps.sshtunnel
    ps.pymysql
    ps.pyregion
    ps.ipython
  ]);

  src = fetchGit {
    url = "git@github.com:mhardcastle/ddf-pipeline.git";
    rev = "c22ac7cb4930a38fe43983bf82432925d465652b";
    ref = "HackathonRennes";
  };

  sky-catalogs = stdenv.mkDerivation {
    pname = "ddf-pipeline-catalogs";
    version = "1.0";
    src = fetchurl {
      url = "https://sdrive.cnrs.fr/public.php/dav/files/qDa8owWokGEaGBK";
      name = "CATALOGS.zip";
      sha256 = "sha256-ig7b68Z2EyZiUfmHGwnFiMHIECNo2vEWEEXswm1NcB0=";
    };
    nativeBuildInputs = [ unzip ];
    unpackCmd = "unzip $curSrc";
    installPhase = ''
      mkdir -p $out
      cp -r * $out/
    '';
  };

  measures-data = stdenv.mkDerivation {
    pname = "casacore-measures";
    version = "unstable";
    src = fetchurl {
      url = "https://www.astron.nl/iers/WSRT_Measures.ztar";

      sha256 = "sha256-U1QKRGihaqRTAqh/SL7A8gYz1hdnXK4JZnEbl0vpWDc=";
    };
    sourceRoot = ".";
    unpackCmd = "tar -zxf $curSrc";
    installPhase = ''
      mkdir -p $out/share/casacore/data
      cp -r * $out/share/casacore/data/
    '';
  };

  pythonpath = lib.concatStringsSep ":" [
    "$out/lib/ddf-pipeline/scripts"
    "$out/lib/ddf-pipeline/utils"
    "$out/lib/ddf-pipeline/others"
    "$out/lib/ddf-pipeline"
    "${py}/${python3.sitePackages}"
  ];
in
stdenv.mkDerivation {
  pname = "ddf-pipeline";
  version = "HackathonRennes";
  inherit src;

  nativeBuildInputs = [ makeWrapper openmpi];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/ddf-pipeline $out/bin $out/bin/mpi $out/share/ddf-pipeline

    cp -r scripts utils misc others $out/lib/ddf-pipeline/

    commonArgs=(
      --prefix PYTHONPATH          : "${pythonpath}"
      --prefix LD_LIBRARY_PATH     : "${dysco}/lib"
      --prefix PATH                : "${kill-ms}/bin"
      --prefix PATH                : "${ddfacet}/bin"
      --set    OPENBLAS_NUM_THREADS  1
      --set    OPENBLAS_MAX_THREADS  1
      --set    PYTHONHASHSEED        0
      --set-default NUMEXPR_MAX_THREADS 96
      --set    DDF_PIPELINE_CATALOGS "${sky-catalogs}"
      --set CASAPATH                 "${measures-data}/share/casacore really"
    )

    for script in $out/lib/ddf-pipeline/scripts/*.py; do
      name=$(basename "$script" .py)

      makeWrapper ${py}/bin/python "$out/bin/$name" \
        --add-flags "$script" \
        "''${commonArgs[@]}"

      # The user still needs to pass -machinefile $OAR_NODEFILE -np N at call time
      makeWrapper ${openmpi}/bin/mpirun "$out/bin/mpi/$name" \
      --add-flags "--mca plm_rsh_agent oarsh" \
      --add-flags "-x CASAPATH=${measures-data}/share/casacore/data" \
      --add-flags "-x PYTHONPATH=${pythonpath}" \
      --add-flags "-x LD_LIBRARY_PATH=${dysco}/lib" \
      --add-flags "-x PATH=${kill-ms}/bin:${ddfacet}/bin:$PATH" \
      --add-flags "-x OPENBLAS_NUM_THREADS=1" \
      --add-flags "-x PYTHONHASHSEED=0" \
      --add-flags "${py}/bin/python $script"
    done


    runHook postInstall
  '';

  passthru = {
    inherit py;
    catalogs = sky-catalogs;
    measures = measures-data;
  };

  meta = {
    description = "LOFAR HBA imaging pipeline with pre-baked sky catalogs";
    license = lib.licenses.gpl2;
    mainProgram = "ddf-pipeline";
  };
}