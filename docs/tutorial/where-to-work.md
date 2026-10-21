
# Where to work
## You are defining the architecture

Start with `topology.nix`. Change it when the machine roles, node count,
networking, shared storage, or SLURM layout changes. Change `flake.nix` only
when the architecture needs a new pinned dependency or NixOS module.

## You are configuring a service

Work under `config/ebuffer/` or `config/ebservice/` for service settings. The
NixOS role that enables each service remains in `topology.nix`.

## You are adding a scientific workload

Create `apps/<name>/` with a NixOS module in `default.nix` and an NXC test
script in `test.nix`. The module declares `exa-atow.apps.<name>.enable`, which
installs the package, and `exa-atow.apps.<name>.testFixtures`, which stages
the test job. Import the directory from `apps/default.nix`, then add a
composition to `compositions.nix` that enables the app. Modules should not
redefine the shared topology.

To combine apps, or to install different apps on different compute nodes,
enable different apps per node in `compositions.nix`; see
`heterogeneous-cluster`. Each compute node advertises the apps it enables as
SLURM features.

## You are validating the architecture

Readiness checks that every composition must pass live in `topology.nix`. Put
app fixtures in the app module behind `testFixtures`, and assertions in
`apps/<name>/test.nix`. The Python client under
`e2e/` is optional; use it only to exercise the ebservice API path.

## You are deploying or running it

Use the `justfile`; it is the supported entry point for normal operations.
The helpers under `scripts/` expose a running local deployment and launch its
host test. Operators normally do not need to edit the Nix modules.
