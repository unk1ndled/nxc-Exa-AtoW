
# Where to work
## You are defining the architecture

Start with `cluster/topology.nix`. Change it when the machine roles,
networking, shared storage, or SLURM layout changes. Change `flake.nix` only
when the architecture needs a new pinned dependency or NixOS module. Node counts
and the apps on each node belong to the compositions in `compositions.nix`.

## You are configuring a service

Work under `cluster/ebuffer/` or `cluster/ebservice/` for service settings.
The service package and its NixOS module are in `pkgs/ebuffer/` and
`pkgs/ebservice/`; the role that enables each service remains in
`cluster/topology.nix`.

## You are adding a scientific workload

Create `pkgs/<name>/` with the package in `package.nix`, a NixOS module in
`default.nix`, and an NXC test script in `test.nix`. Add the package to
`pkgs/packages.nix`. The module declares `exa-atow.pkgs.<name>.enable`, which
installs the package, and `exa-atow.pkgs.<name>.testFixtures`, which stages
the test job. Import the directory from `pkgs/modules.nix`, then add a
composition to `compositions.nix` that enables the app. Modules should not
redefine the shared topology.

To combine apps, or to install different apps on different compute nodes,
declare one compute group per node type in `compositions.nix`; see the
[quick start](quickstart.md#3-declare-your-own-cluster). Each compute node advertises the apps it enables as
SLURM features.

## You are validating the architecture

Readiness checks that every composition must pass live in `cluster/topology.nix`. Put
app fixtures in the app module behind `testFixtures`, and assertions in
`pkgs/<name>/test.nix`. The Python client under
`clients/python-e2e/` is optional; use it only to exercise the ebservice API path.

## You are deploying or running it

Use the `justfile`; it is the supported entry point for normal operations.
`scripts/tunnel.sh` exposes a running local deployment on loopback ports; the
optional client under `clients/python-e2e/` carries its own launch scripts. Operators normally do not need to edit the Nix modules.
