import math
import re
import shlex
from pathlib import Path

from common import E2EApplication, run_e2e


ROOT = Path(__file__).resolve().parent
OPENQCD_INPUT = ROOT / "openqcd-ym1.in"
OPENQCD_LOG = "openqcd-e2e.log"


def validate_openqcd_log(content: str) -> float:
    for marker in (
        "Simulation of the SU(3) gauge theory",
        "Program version openQCD-2.0",
        "8x4x4x4 lattice, 4x4x4x4 local lattice",
        "2x1x1x1 process grid",
        "Configuration no 1 exported",
    ):
        if marker not in content:
            raise RuntimeError(f"OpenQCD log is missing {marker!r}")

    trajectories = re.findall(r"^Trajectory no (\d+)$", content, re.MULTILINE)
    if trajectories != ["1"]:
        raise RuntimeError(f"OpenQCD log has unexpected trajectories: {trajectories}")

    plaquettes = re.findall(
        r"^Average plaquette = ([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[Ee][+-]?\d+)?)$",
        content,
        re.MULTILINE,
    )
    if len(plaquettes) != 1:
        raise RuntimeError("OpenQCD log does not contain exactly one plaquette value")
    plaquette = float(plaquettes[0])
    if not math.isfinite(plaquette) or not -1.0 <= plaquette <= 1.0:
        raise RuntimeError(f"OpenQCD returned an invalid plaquette value: {plaquette}")
    return plaquette


def validate_output(content: str) -> tuple[str, ...]:
    plaquette = validate_openqcd_log(content)
    return (f"Average plaquette: {plaquette:.6f}",)


def scheduler_core(job_dir: Path, executable: Path) -> str:
    quoted_job_dir = shlex.quote(str(job_dir))
    quoted_executable = shlex.quote(str(executable))
    input_file = shlex.quote(str(job_dir / OPENQCD_INPUT.name))
    log_file = shlex.quote(str(job_dir / OPENQCD_LOG))
    configuration_file = shlex.quote(str(job_dir / "openqcd-e2en1"))
    return (
        f"cd {quoted_job_dir} && "
        "srun --mpi=pmix --nodes=2 --ntasks=2 --ntasks-per-node=1 "
        f"{quoted_executable} -i {input_file} -noms && "
        f"test -s {log_file} && "
        f"test \"$(grep -c '^Trajectory no ' {log_file})\" -eq 1 && "
        f"grep -q '^Trajectory no 1$' {log_file} && "
        f"grep -q '^Average plaquette = ' {log_file} && "
        f"grep -q '8x4x4x4 lattice, 4x4x4x4 local lattice' {log_file} && "
        f"grep -q '2x1x1x1 process grid' {log_file} && "
        f"grep -q '^Configuration no 1 exported' {log_file} && "
        f"test -s {configuration_file}"
    )


APPLICATION = E2EApplication(
    name="openqcd",
    microservice_name="nxc-e2e-openqcd",
    mime_type="application/x-nxc-openqcd",
    job_config=ROOT / "openqcd-job.ini",
    input_files=(OPENQCD_INPUT,),
    output_name=OPENQCD_LOG,
    diagnostic_files=(OPENQCD_LOG,),
    default_timeout=300,
    success_message="API -> runtime -> two-node SLURM -> OpenQCD HMC",
    scheduler_core=scheduler_core,
    validate_output=validate_output,
)


def main() -> None:
    run_e2e(APPLICATION)


if __name__ == "__main__":
    main()
