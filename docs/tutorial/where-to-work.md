# Where to work

## You are adding a reusable capability

Work under `nix/modules/applications/`. Modules install packages and configure
their runtime environment, but do not choose machine names or composition
identities.

## You are defining a runnable system

Add or change an entry in `nix/profiles/default.nix`. A uniform profile uses
`modules`; a heterogeneous profile uses `frontendModules` and `computeNodes`.
The same profile entry selects its check, making placement and evidence one
reviewable unit.

## You are changing shared infrastructure

Work in `nix/lib/mk-topology.nix` when machine roles, shared storage, Munge, or
SLURM structure changes. `nix/lib/mk-compositions.nix` should contain only
profile-schema validation and normalization. Change `flake.nix` for pinned
dependencies, overlays, or upstream NixOS modules.

## You are validating a profile

Put NXC assertions in `checks/nixos/profiles/`; shared service and scheduler
readiness belongs in `checks/nixos/with-readiness.nix`. Use `checks/host/` for
the full API-to-SLURM workflow, application contracts, fixtures, and unit tests.

## You are adapting a deployment target

Use `tools/vm/` for local VM transport, `tools/grid5000/` for Grid'5000, and
`tools/host/` for launchers shared across targets. These tools may adapt
transport and lifecycle details, but must not redefine modules or profiles.

Normal users should invoke these layers through the root `justfile`.
