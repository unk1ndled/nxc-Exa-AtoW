
# Where to work
## You are defining the architecture

Start with `topology.nix`. Change it when the machine roles, node count,
networking, shared storage, or SLURM layout changes. Change `flake.nix` only
when the architecture needs a new pinned dependency or NixOS module.

## You are configuring a service

Work under `config/ebuffer/` or `config/ebservice/` for service settings. The
NixOS role that enables each service remains in `topology.nix`.

## You are adding a scientific workload

Create `apps/<name>/` with a NixOS module in `default.nix` that installs the
package, and an NXC test in `test.nix`. The directory name becomes the
composition name; no catalog needs updating. Modules should not redefine the
shared topology.

To combine apps, or to install different apps on different compute nodes, add
a file under `compositions/`. It returns `frontendModules`, `computeNodes`
(each with `modules` and optional SLURM `features`), `testModules`, and
`testScript`; see `compositions/heterogeneous-cluster.nix`.

## You are validating the architecture

Readiness checks that every composition must pass live in `topology.nix`. Put
app fixtures and assertions in `apps/<name>/test.nix`. The Python client under
`e2e/` is optional; use it only to exercise the ebservice API path.

## You are deploying or running it

Use the `justfile`; it is the supported entry point for normal operations.
The helpers under `scripts/` expose a running local deployment and launch its
host test. Operators normally do not need to edit the Nix modules.
