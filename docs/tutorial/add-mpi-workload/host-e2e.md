# Create the host E2E contract

The NXC test proves the topology internally. This chapter adds the independent
host test that enters through ebuffer and ebservice, submits over the frontend
SSH tunnel, and validates the returned artifact.

## 5. Describe the API-to-SLURM job

Create `e2e/mpi-calculator-job.ini`:

```ini
[JOB]
job_name = ebuffer-mpi-calculator-e2e

[INSTALLATION]
app_name = mpi-calculator
app_dir = /run/current-system/sw/bin
run_dir = /users/user1

[RESOURCES]
partition = main
nodes = 2
tasks = 2
cpus_per_task = 1
time = 00:02:00

[MODULES]
module_purge = false
modules =
```

`app_name` and `app_dir` identify the executable inside the NixOS system
profile. The shared lifecycle reads the resource section when constructing
the remote job. Keep it consistent with both the batch example and the
program's two-rank requirement.

The calculator has no uploaded input file. Its operands are fixed test data in
the application contract. For a program that consumes a mesh, parameter file,
or dataset, list those paths in `input_files`; `e2e/common.py` will create input
ebuffers and stage their bytes in the remote job directory. The OpenQCD
contract is the working example of that pattern.

## 6. Write the application-specific host contract

Create `e2e/mpi_calculator_e2e.py`:

```python
import re
import shlex
from pathlib import Path

from common import E2EApplication, run_e2e


ROOT = Path(__file__).resolve().parent
CALCULATOR_OUTPUT = "mpi-calculator.out"


def validate_output(content: str) -> tuple[str, ...]:
    rank_pattern = re.compile(r"^rank (\d+) operand (-?\d+) on (\S+)$")
    lines = [line for line in content.splitlines() if line]
    rank_matches = [
        match
        for line in lines
        if (match := rank_pattern.fullmatch(line)) is not None
    ]

    if len(rank_matches) != 2:
        raise RuntimeError(f"calculator returned unexpected rank lines: {lines}")

    rank_data = {
        int(match.group(1)): (int(match.group(2)), match.group(3))
        for match in rank_matches
    }
    if len(rank_data) != 2 or set(rank_data) != {0, 1}:
        raise RuntimeError(f"calculator returned unexpected ranks: {rank_data}")

    operands = {rank: operand for rank, (operand, _) in rank_data.items()}
    if operands != {0: 19, 1: 23}:
        raise RuntimeError(f"calculator returned unexpected operands: {operands}")

    hosts = {host for _, host in rank_data.values()}
    if len(hosts) != 2:
        raise RuntimeError(
            f"calculator did not run on two distinct nodes: {sorted(hosts)}"
        )

    result_lines = [line for line in lines if line.startswith("result ")]
    if result_lines != ["result add = 42"]:
        raise RuntimeError(f"calculator returned an invalid result: {result_lines}")

    return (f"19 + 23 = 42 across {', '.join(sorted(hosts))}",)


def scheduler_core(job_dir: Path, executable: Path) -> str:
    quoted_job_dir = shlex.quote(str(job_dir))
    quoted_executable = shlex.quote(str(executable))
    output_file = shlex.quote(str(job_dir / CALCULATOR_OUTPUT))
    return (
        f"cd {quoted_job_dir} && "
        "output=$(srun --mpi=pmix --nodes=2 --ntasks=2 --ntasks-per-node=1 "
        f"{quoted_executable} add 19 23) && "
        f'printf "%s\\n" "$output" > {output_file} && '
        'test "$(printf "%s\\n" "$output" | '
        'grep -c \'^rank [01] operand \')" -eq 2 && '
        'printf "%s\\n" "$output" | grep -q \'^result add = 42$\''
    )


APPLICATION = E2EApplication(
    name="mpi-calculator",
    microservice_name="nxc-e2e-mpi-calculator",
    mime_type="application/x-nxc-mpi-calculator",
    job_config=ROOT / "mpi-calculator-job.ini",
    input_files=(),
    output_name=CALCULATOR_OUTPUT,
    diagnostic_files=(CALCULATOR_OUTPUT,),
    default_timeout=180,
    success_message="API -> runtime -> two-node SLURM -> MPI calculator",
    scheduler_core=scheduler_core,
    validate_output=validate_output,
)


def main() -> None:
    run_e2e(APPLICATION)


if __name__ == "__main__":
    main()
```

An application contract has two active parts:

- `scheduler_core` returns the shell body executed in the remote job
  directory. It launches the program, writes the output file promised by the
  contract, and performs cheap remote checks.
- `validate_output` runs after that file has made the return journey through
  an output ebuffer. It performs the richer semantic checks: exact operands,
  correct arithmetic, both ranks, and two distinct hosts.

Keep shell quoting explicit. Job directories and executable paths originate
from configuration, so the contract uses `shlex.quote` before inserting them
into a command. The fixed integers do not need quoting.

The shared `run_e2e` function does the plumbing that should not be copied into
each application: it creates the API objects, starts the runtime, transfers
ebuffers, submits and monitors SLURM, validates terminal scheduler metadata,
downloads output, and cleans up.

## 7. Register the host contract

The `just test` path ends in `e2e/minimal-e2e.py`. Import the calculator and
add it to `APPLICATIONS`:

```python
from common import run_e2e
from mpi_calculator_e2e import APPLICATION as MPI_CALCULATOR
from mpi_hello_e2e import APPLICATION as MPI_HELLO
from openqcd_e2e import APPLICATION as OPENQCD


APPLICATIONS = {
    MPI_CALCULATOR.name: MPI_CALCULATOR,
    MPI_HELLO.name: MPI_HELLO,
    OPENQCD.name: OPENQCD,
}
```

No `justfile`, tunnel script, composition factory, or flake change is needed.
Those pieces already accept a workload selected from the closed catalogs.

You can confirm dispatcher registration without starting VMs:

```console
$ nix develop --command e2e-fhs -c \
    "uv run --project e2e python e2e/minimal-e2e.py --help"
```

The choices should now include `mpi-calculator`.

Continue with [Run, debug, and adapt the workload](run-and-debug.md).
