import argparse

from common import run_e2e
from mpi_hello_e2e import APPLICATION as MPI_HELLO
from openqcd_e2e import APPLICATION as OPENQCD


APPLICATIONS = {
    MPI_HELLO.name: MPI_HELLO,
    OPENQCD.name: OPENQCD,
}


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run an application E2E through NXC and SLURM")
    parser.add_argument(
        "--app",
        required=True,
        choices=sorted(APPLICATIONS),
        help="application/composition to exercise",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)
    run_e2e(APPLICATIONS[args.app])


if __name__ == "__main__":
    main()
