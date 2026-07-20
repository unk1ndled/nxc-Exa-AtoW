# Reproducible HPC-as-a-Service with NixOS Compose




This book explains a small but complete scientific-computing stack: an API
accepts a job and its files, a runtime translates that request into a SLURM
batch job, and MPI runs the selected scientific program on two compute nodes.
Nix and NixOS Compose describe the software and the six machines as one
reproducible composition.

The repository ships two compositions:

- `mpi-hello`  A fast diagnostic proving that two MPI ranks ran on two distinct compute nodes. 
- `openqcd`  A small but genuine OpenQCD 2.0 HMC run that exercises input transfer and scientific-output validation. 

Both workloads reuse the same ebuffer, ebservice, shared storage, SLURM, SSH,
test lifecycle, and deployment machinery. Only the application package and its
contract change.

> This is a local development demonstrator, not a production HPC service. Its
> tiny VM resources, bootstrap credentials, in-memory data, disabled
> firewalls, deterministic Munge key, and loopback SSH tunnels are deliberate
> test choices.

## Choose a path

- To understand the motivation, begin with
  [Where this fits in Exa-AToW](concepts/exa-atow.md).
- To run the existing compositions, follow the [quick start](tutorial/quickstart.md).
- To bring your own scientific code, work through
  [Add your own MPI workload](tutorial/add-mpi-workload/README.md).
