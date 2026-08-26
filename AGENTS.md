# Repository Guidelines

## Project Structure & Module Organization

The NixOS-Compose topology lives in `composition.nix`; `compositions.nix` combines workload definitions from `software/` with in-topology tests from `e2e/nxc/`. Host-side API-to-SLURM scenarios are implemented in `e2e/common.py`, with application contracts in `e2e/mpi_hello_e2e.py` and `e2e/openqcd_e2e.py`. Service configuration belongs under `config/`, helper scripts under `scripts/`, and sample batch jobs under `examples/`. Documentation source is in `docs/`; `book/`, `build/`, and `deploy/` are generated outputs and should not be edited by hand.

Treat software modules as reusable components, not composition identities: one composition may install one or several modules on its frontend and compute nodes. Catalog values in `software/default.nix` accept either a module or a list. Keep software-selection and E2E keys aligned, and provide composition-level validation for combined selections.

## Build, Test, and Development Commands

Use the root `justfile` as the command entry point:

- `just install` creates/synchronizes `e2e/.venv` from `e2e/uv.lock`.
- `just check` evaluates the flake and its outputs.
- `just build vm mpi-hello` builds a selected composition; defaults are `vm` and `openqcd` (the argument is currently named `workload`).
- `just up vm openqcd` starts the topology in the foreground.
- `just nxc-test [composition]` runs the composition's test inside NXC.
- `just test [composition] [application]` runs one host E2E against an already running VM deployment.
- `just docs` builds mdBook; `just docs-serve` serves it at `127.0.0.1:3000`.

## Coding Style & Naming Conventions

Follow surrounding style: four-space indentation and type hints in Python; two-space indentation in Nix, YAML, and TOML; `snake_case` for Python functions, `UPPER_CASE` for constants, and kebab-case software/composition names such as `mpi-hello`. Shell scripts should use Bash with `set -euo pipefail`. No formatter is configured, so keep changes focused and consistent with adjacent code.

## Testing Guidelines

There is no documented coverage threshold. Run `just check` for Nix changes and the relevant `just nxc-test` and `just test` for topology, software, or E2E changes. E2E modules are executable scenario drivers rather than conventional `test_*.py` suites; validation failures should raise clear `RuntimeError` messages. Run `just docs` after documentation or navigation changes.

## Commit & Pull Request Guidelines

History favors short, imperative subjects, sometimes with prefixes such as `feat :`, `fix :`, `book :`, or `doc :`. Keep each commit narrowly scoped. Pull requests should explain the affected workload or layer, list commands run, link relevant issues, and include screenshots for rendered documentation changes. Do not commit credentials, SSH keys, `.venv`, logs, or generated deployment artifacts.
