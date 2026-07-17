# Technology stack

The stack combines tools from several communities. Similar-sounding concepts
have deliberately different jobs.

| Technology | Role here | Start reading |
| --- | --- | --- |
| Just | handy tool for running commands and scripts |  [Repository](https://github.com/casey/just)
| Nix | Pins dependencies and builds packages as immutable store paths. | [How Nix works](https://nixos.org/guides/how-nix-works/) |
| NixOS | Declares packages, users, services, filesystems, and networking for each node. | [NixOS manual](https://nixos.org/manual/nixos/stable/) |
| NixOS Compose (NXC) | Builds and launches a distributed set of NixOS roles using a selected flavour such as QEMU VMs or Docker. | To be efficient go to [next page](./nxc.md) (official [doc](https://nixos-compose.gitlabpages.inria.fr/nixos-compose/) or [tuto](https://nixos-compose.gitlabpages.inria.fr/tuto-nxc/01_intro.html))|
| ebuffer | Provides ephemeral input and output buffers through an API. | [the next next page](./ebuffer.md) |
| ebservice | Stores application, runtime, and pipeline-job control objects. | [the next next page](./ebuffer.md) |
| SLURM | Allocates nodes, queues jobs, launches steps, and reports scheduler state. | [SLURM quick start](https://slurm.schedmd.com/quickstart.html) |
| Open MPI | Implements the MPI communication model used by both workloads. | [Open MPI documentation](https://docs.open-mpi.org/en/main/) |
| PMIx | Connects the scheduler's process launch to the MPI runtime. | [SLURM MPI guide](https://slurm.schedmd.com/mpi_guide.html) |
| OpenQCD | Supplies the real lattice-QCD `ym1` application used by the scientific smoke test. | [OpenQCD project](https://luscher.web.cern.ch/luscher/openQCD/) |
