# Reproducible HPC-as-a-Service with NixOS Compose




This book explains a small but complete scientific-computing stack: an API
accepts a job and its files, a runtime translates that request into a SLURM
batch job, and MPI runs the selected scientific program on two compute nodes.
Nix and NixOS Compose describe the software and the six machines as one
reproducible composition.

The repository ships one composition, `openqcd`: ebuffer, ebservice, a SLURM
frontend and controller, and two compute nodes running a small but genuine
OpenQCD 2.0 HMC job that exercises input transfer and scientific-output
validation.

Other cluster shapes are one entry each in `compositions.nix` and reuse the
same ebuffer, ebservice, shared storage, SLURM, SSH, test lifecycle, and
deployment machinery. A composition enables apps on the frontend and on groups
of identical compute nodes, each with a `count`; compute nodes advertise their
apps as SLURM features.

> This is a local development demonstrator, not a production HPC service. Its
> tiny VM resources, bootstrap credentials, in-memory data, disabled
> firewalls, deterministic Munge key, and loopback SSH tunnels are deliberate
> test choices.

## Choose a path

- To understand the motivation, begin with
  [Where this fits in Exa-AToW](concepts/exa-atow.md).
- To run the default composition and declare your own, follow the [quick start](tutorial/quickstart.md).
- To bring your own scientific code, work through
  [Add your own MPI workload](tutorial/add-mpi-workload/README.md).
