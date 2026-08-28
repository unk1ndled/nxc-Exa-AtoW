# Repository Guidelines

## Project Structure & Module Organization

The repository follows Nix's modules/profiles/checks model. Reusable NixOS modules live in `nix/modules/`; `nix/profiles/default.nix` is the single composition catalog and owns both module placement and the profile's NXC check. `nix/lib/` validates profiles and constructs the shared topology. NXC checks and their batch-job fixtures live in `checks/nixos/`, while host API-to-SLURM checks and their locked Python environment live in `checks/host/`. Deployment helpers belong under `tools/`, and service data under `config/`. Documentation source is in `docs/`; `book/`, `build/`, and `deploy/` are generated outputs and should not be edited by hand.

Treat application modules as reusable capabilities, not composition identities: a profile may install one or several modules uniformly or assign them per compute node. Every entry in `nix/profiles/default.nix` must declare its NXC check alongside its placement. Keep deployment-specific behavior out of modules and composition-specific assertions out of the topology factory.

## Build, Test, and Development Commands

Use the root `justfile` as the command entry point:

- `just install` creates/synchronizes `checks/host/.venv` from `checks/host/uv.lock`.
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
