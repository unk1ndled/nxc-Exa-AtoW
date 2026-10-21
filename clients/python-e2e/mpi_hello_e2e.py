import re
import shlex
from pathlib import Path

from common import E2EApplication, run_e2e


ROOT = Path(__file__).resolve().parent
MPI_HELLO_OUTPUT = "mpi-hello.out"


def validate_output(content: str) -> tuple[str, ...]:
    pattern = re.compile(r"^Hello from rank (\d+) of (\d+) on (\S+)$")
    lines = [line for line in content.splitlines() if line]
    matches = [pattern.fullmatch(line) for line in lines]
    if len(matches) != 2 or any(match is None for match in matches):
        raise RuntimeError(f"MPI hello returned unexpected lines: {lines}")

    rank_data = [
        (int(match.group(1)), int(match.group(2)), match.group(3))
        for match in matches
        if match is not None
    ]
    ranks = {rank for rank, _, _ in rank_data}
    sizes = {size for _, size, _ in rank_data}
    hosts = {host for _, _, host in rank_data}
    if ranks != {0, 1} or sizes != {2}:
        raise RuntimeError(f"MPI hello returned unexpected rank data: {rank_data}")
    if len(hosts) != 2:
        raise RuntimeError(f"MPI hello did not run on two distinct nodes: {sorted(hosts)}")
    return (f"MPI ranks 0 and 1 ran on {', '.join(sorted(hosts))}",)


def scheduler_core(job_dir: Path, executable: Path) -> str:
    quoted_job_dir = shlex.quote(str(job_dir))
    quoted_executable = shlex.quote(str(executable))
    output_file = shlex.quote(str(job_dir / MPI_HELLO_OUTPUT))
    return (
        f"cd {quoted_job_dir} && "
        "output=$(srun --mpi=pmix --nodes=2 --ntasks=2 --ntasks-per-node=1 "
        f"{quoted_executable}) && "
        f'printf "%s\\n" "$output" > {output_file} && '
        'test "$(printf "%s\\n" "$output" | grep -c "^Hello from rank")" -eq 2 && '
        'printf "%s\\n" "$output" | grep -q "rank 0 of 2" && '
        'printf "%s\\n" "$output" | grep -q "rank 1 of 2"'
    )


APPLICATION = E2EApplication(
    name="mpi-hello",
    microservice_name="nxc-e2e-mpi-hello",
    mime_type="application/x-nxc-mpi-hello",
    job_config=ROOT / "mpi-hello-job.ini",
    input_files=(),
    output_name=MPI_HELLO_OUTPUT,
    diagnostic_files=(MPI_HELLO_OUTPUT,),
    default_timeout=180,
    success_message="API -> runtime -> two-node SLURM -> MPI hello",
    scheduler_core=scheduler_core,
    validate_output=validate_output,
)


def main() -> None:
    run_e2e(APPLICATION)


if __name__ == "__main__":
    main()
