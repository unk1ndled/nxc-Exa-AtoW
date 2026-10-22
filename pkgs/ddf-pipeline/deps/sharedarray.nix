{
  lib,
  python3,
  fetchPypi,
}:

python3.pkgs.buildPythonApplication rec {
  pname = "sharedarray";
  version = "3.2.4";
  pyproject = true;

  src = fetchPypi {
    pname = "SharedArray";
    inherit version;
    hash = "sha256-uLjRiREMAjud5QL5OW/yWR9mD7LJY36xP8ryMxJ+UL4=";
  };

  build-system = [
    python3.pkgs.numpy
    python3.pkgs.setuptools
    python3.pkgs.wheel
  ];

  pythonImportsCheck = [
    "SharedArray"
  ];

  meta = {
    description = "Share numpy arrays between processes";
    homepage = "https://pypi.org/project/SharedArray/";
    license = lib.licenses.gpl2Only;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "sharedarray";
  };
}
