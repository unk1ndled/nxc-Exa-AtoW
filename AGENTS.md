# Repository Guidelines

## Project Structure & Module Organization

The root holds only files a tool expects there (`flake.nix`, `flake.lock`, `nxc.json`, `justfile`) plus `compositions.nix`. `cluster/` is the shared platform: `cluster/topology.nix` defines ebuffer, ebservice, SLURM, shared storage, and the readiness checks run before every test, and `cluster/ebuffer/` and `cluster/ebservice/` hold the service configuration. Each app under `apps/` is a NixOS module with an `exa-atow.apps.<name>.enable` option (plus `testFixtures` for its NXC test inputs); `apps/default.nix` lists them, and shared modules such as `apps/openmpi.nix` sit beside them. `compositions.nix` lists every composition as per-node configuration that enables apps; compute nodes advertise their enabled apps as SLURM features. An app directory holds its module (`default.nix`), sources, SLURM job, and NXC test script (`test.nix`). `clients/` holds optional clients that drive a running deployment; `clients/python-e2e/` is the Python client for the ebservice API path, with its launch scripts. `scripts/` holds helpers that work without any client. Documentation is in `docs/` (`book.toml`, source in `docs/src/`); `docs/book/`, `build/`, and `deploy/` are generated outputs and should not be edited by hand.

## Design Invariants

- Human readability comes first. Prefer the plain, obvious version over defensive or clever machinery; a new contributor should follow one app from its Nix module to its NXC test without reading Python.
- Nix is the package manager and configuration language, NXC is the orchestration and test layer. Building, deploying, and testing must not require any other client, language runtime, or package manager.
- Clients under `clients/`, such as the Python ebsclient E2E, are optional. Apps must not depend on them; they may read from `apps/`, never the reverse.
- Wrappers (`justfile`, `scripts/`) exist to save effort. Each `just` recipe should stay a short, readable call to `nix` or `nxc`; do not add wrapper layers that become necessary to understand the project.
- Keep each concept under one name and in one place. Workarounds for upstream bugs are labelled as such, next to the code they affect.

## Build, Test, and Development Commands

Use the root `justfile` as the command entry point:

- `just install` creates/synchronizes `clients/python-e2e/.venv` from `clients/python-e2e/uv.lock`.
- `just check` evaluates the flake and its outputs.
- `just build vm mpi-hello` builds a selected composition; defaults are `vm` and `openqcd` (the argument is currently named `workload`).
- `just up vm openqcd` starts the topology in the foreground.
- `just nxc-test [composition]` runs the composition's test inside NXC.
- `just test [composition] [application]` runs one host E2E against an already running VM deployment.
- `just docs` builds mdBook; `just docs-serve` serves it at `127.0.0.1:3000`.

## Coding Style & Naming Conventions

Follow surrounding style: four-space indentation and type hints in Python; two-space indentation in Nix, YAML, and TOML; `snake_case` for Python functions, `UPPER_CASE` for constants, and kebab-case software/composition names such as `mpi-hello`. Shell scripts should use Bash with `set -euo pipefail`. No formatter is configured, so keep changes focused and consistent with adjacent code.

## Testing Guidelines

There is no documented coverage threshold. Run `just check` for Nix changes and the relevant `just nxc-test` for topology or app changes. Run `just test` only when changing the optional `clients/python-e2e/` client. Run `just docs` after documentation or navigation changes.

## Commit & Pull Request Guidelines

History favors short, imperative subjects, sometimes with prefixes such as `feat :`, `fix :`, `book :`, or `doc :`. Keep each commit narrowly scoped. Pull requests should explain the affected workload or layer, list commands run, link relevant issues, and include screenshots for rendered documentation changes. Do not commit credentials, SSH keys, `.venv`, logs, or generated deployment artifacts.
