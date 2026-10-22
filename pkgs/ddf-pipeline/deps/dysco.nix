{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  gsl,

  casacore,
  doxygen,
  boost,
}:

stdenv.mkDerivation rec {
  
  pname = "dysco";
  version = "unstable-2024-03-14";

  src = fetchFromGitHub {
    owner = "aroffringa";
    repo = "dysco";
    rev = "36b61add9b88be4a6c65722a0418d47c37af9035";
    hash = "sha256-2MuM9FjBYbqLF9gRA2FdXSdUUGCCh+2BMSqTP/PotYM=";
  };
  
  # TODO : https://github.com/aroffringa/dysco/issues/12

  nativeBuildInputs = [
    cmake
    doxygen
  ];

  buildInputs = [
    gsl
    casacore
    boost
  ];

  cmakeFlags = [ ];
  meta = {
    description = "Compression scheme for radio astronomy data";
    homepage = "https://github.com/aroffringa/dysco";
    changelog = "https://github.com/aroffringa/dysco/blob/${src.rev}/CHANGELOG";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.all;
  };
}
