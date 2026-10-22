{
  lib,
  stdenv,
  fetchurl,
  openmpi,
}:

stdenv.mkDerivation rec {
  pname = "openQCD";
  version = "2.0";

  src = fetchurl {
    url = "https://luscher.web.cern.ch/luscher/openQCD/${pname}-${version}.tar.gz";
    hash = "sha256-25o7uUu48NAZBaPfUa5EfUbYFr0kteIDRgdVAdk7jTU=";
  };

  postPatch = ''
    substituteInPlace include/global.h \
      --replace-fail '#define L0 8' '#define L0 4' \
      --replace-fail '#define L1 8' '#define L1 4' \
      --replace-fail '#define L2 8' '#define L2 4' \
      --replace-fail '#define L3 8' '#define L3 4'
  '';

  NIX_CFLAGS_COMPILE = toString [
    "-O2"
    "-march=x86-64"
    "-mtune=generic"
    "-Wno-error=maybe-uninitialized"
    "-Wno-error=stringop-truncation"
  ];

  buildInputs = [ openmpi ];
  preBuild = ''
    cd main
  '';

  makeFlags = [ "GCC=mpicc" ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/run $out/app/${pname}-${version} $out/bin
    # full set of executables
    # cp cvt1 ms1 ms2 ms3 ms4 qcd1 qcd2 xms1 xms2 ym1 ym2 $out/app/
    # we only neeed ym1 for the benjamin's demo
    cp ym1 $out/app/
    ln -s $out/app/ym1 $out/bin/ym1

    make clean
    cp -a ../* $out/app/${pname}-${version}
    runHook postInstall
  '';

  meta = with lib; {
    description = "openQCD - A simulation program for lattice QCD";
    homepage = "https://luscher.web.cern.ch/luscher/openQCD/";
    license = licenses.gpl2Plus;
    platforms = platforms.unix;
  };
}
