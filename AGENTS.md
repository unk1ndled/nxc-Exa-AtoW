# Repository Guidelines

## Project Structure & Module Organization

The root holds only files a tool expects there (`flake.nix`, `flake.lock`, `nxc.json`, `justfile`) plus `compositions.nix`. `cluster/` instantiates the shared system and holds no package definitions: `cluster/topology.nix` defines the roles (ebuffer, ebservice, SLURM, shared storage) and the readiness checks run before every test, and `cluster/ebuffer/` and `cluster/ebservice/` hold the service configuration. `pkgs/` holds every package, one directory each, including the platform services: `package.nix` builds it and, when it is deployable, `default.nix` is its NixOS module (`services.ebuffer`, `services.ebservice`, or `exa-atow.pkgs.<name>.{enable,package}` plus `testFixtures` and `test.nix` for an NXC test). Modules never define their package; `pkgs/packages.nix` is the overlay listing every package, `pkgs/modules.nix` imports every `exa-atow.pkgs` module, and shared modules such as `pkgs/openmpi.nix` sit beside them. `compositions.nix` lists every composition as a module setting the options of `cluster/topology.nix`: frontend configuration, `computeGroups.<name> = { count; node; }` (nodes `<name>1..count`), and the test script; compute nodes advertise their enabled packages as SLURM features. `clients/` is only for Exa-AToW infrastructure clients (web apps, notebooks, the Python E2E in `clients/python-e2e/`); library packages go in `pkgs/`. `scripts/` holds helpers that work without any client. Documentation is in `docs/` (`book.toml`, source in `docs/src/`); `docs/book/`, `build/`, and `deploy/` are generated outputs and should not be edited by hand.

## Design Invariants

- Human readability comes first. Prefer the plain, obvious version over defensive or clever machinery; a new contributor should follow one app from its Nix module to its NXC test without reading Python.
- Nix is the package manager and configuration language, NXC is the orchestration and test layer. Building, deploying, and testing must not require any other client, language runtime, or package manager.
- Clients under `clients/`, such as the Python ebsclient E2E, are optional. Nothing in `cluster/` or `pkgs/` may depend on them; they may read from `pkgs/`, never the reverse.
- Wrappers (`justfile`, `scripts/`) exist to save effort. Each `just` recipe should stay a short, readable call to `nix` or `nxc`; do not add wrapper layers that become necessary to understand the project.
- Keep each concept under one name and in one place. Workarounds for upstream bugs are labelled as such, next to the code they affect.

## Build, Test, and Development Commands

Use the root `justfile` as the command entry point:

- `just install` creates/synchronizes `clients/python-e2e/.venv` from `clients/python-e2e/uv.lock`.
- `just check` evaluates the flake and its outputs.
- `just build vm openqcd` builds a selected composition; defaults are `vm` and `openqcd`, the only composition shipped.
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
