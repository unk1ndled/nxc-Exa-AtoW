
# Where to work
## You are defining the architecture

Start with `composition.nix`. Change it when the machine roles, node count,
networking, shared storage, or SLURM layout changes. Change `flake.nix` only
when the architecture needs a new pinned dependency or NixOS module.

## You are configuring a service

Work under `config/ebuffer/` or `config/ebservice/` for service settings. The
NixOS role that enables each service remains in `composition.nix`.

## You are adding a scientific workload

Add its package module under `software/`, then register its name in
`software/default.nix`. The module is injected into the frontend and compute
roles; it should not redefine the shared topology.

A workload is not complete until the same name is added under `e2e/nxc/` with
its deployment checks. If it is submitted through the APIs, also add its
host-side contract and job INI under `e2e/`.

## You are validating the architecture

Use `e2e/nxc/common.nix` for readiness checks that every composition must pass.
Put application fixtures and assertions in `e2e/nxc/<name>.nix`. Use the Python
files under `e2e/` when testing the full path from the APIs to SLURM and back.

## You are deploying or running it

Use the `justfile`; it is the supported entry point for normal operations.
The helpers under `scripts/` expose a running local deployment and launch its
host test. Operators normally do not need to edit the Nix modules.
