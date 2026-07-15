# Canonical HPC Composition

This repository defines one NixOS Compose topology: `hpc`. It deploys an
ebuffer server, ebservice, a SLURM frontend and controller, and two compute
nodes. All roles share one network and are built with the same VM or Docker
flavour.

HPC workloads are plug-ins rather than composition logic. Modules listed in
`software/default.nix` are installed on the frontend and every compute node.
The default `mpi-hello.nix` plug-in builds a small MPI program and composes the
OpenMPI runtime it needs. Add another module for a compiler, library, or
application and import it from `software/default.nix`.

`examples/mpi-hello.sbatch` runs two MPI ranks, one on each compute node. The
composition test submits the equivalent job and checks that both ranks finish.
This verifies package deployment, shared storage, SLURM scheduling, and MPI
launching together.

The ebuffer and ebservice roles contain no workload-specific policy. Their
files under `config/` are bootstrap settings; clients use the services through
their network APIs (`ebuffer` and `ebservice` hostnames inside the composition).

```console
just check
just install
just build
just up
just test
just tunnel
just down
```

With a VM deployment already running, `just tunnel` forwards the ebuffer API
to `http://localhost:8000/api/v1`, the ebservice API to
`http://localhost:8001/api/v1`, and frontend SSH to `localhost:2222`. `just
test` establishes those tunnels, registers a minimal MPI microservice and
runtime through ebservice, submits the job through the client template, and
requires both MPI ranks to finish through SLURM. Internal controller and
compute-node ports remain on the composition network.

The E2E SDK environment is managed by uv. `just install` installs the imported
`ebsclient_package` and `ebstemplate_package` trees as editable packages and
downloads their Python dependencies into `examples/.venv`.

The default flavour is `vm`. Pass `docker` to a recipe, for example
`just build docker`, to build the entire composition as containers.
The VM start recipe defaults QEMU to `-cpu host`, which exposes the CPU
instructions required by the nixpkgs OpenMPI/UCX build. Set `QEMU_OPTS`
explicitly to override it.
