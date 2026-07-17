# Reproducible HPC-as-a-Service with NixOS Compose

This book explains a small but complete scientific-computing stack: an API
accepts a job and its files, a runtime translates that request into a SLURM
batch job, and MPI runs the selected scientific program on two compute nodes.
Nix and NixOS Compose describe the software and the six machines as one
reproducible composition.

The repository ships two compositions:

| Workload | Why it is useful |
| --- | --- |
| `mpi-hello` | A fast diagnostic proving that two MPI ranks ran on two distinct compute nodes. |
| `openqcd` | A small but genuine OpenQCD 2.0 HMC run that exercises input transfer and scientific-output validation. |

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
- [ TODO ]

## What you will learn

By the end of the book, you should be able to explain:

1. why ebuffer, ebservice, SLURM, MPI, and shared storage are separate pieces;
2. how NixOS Compose turns roles into a reproducible multi-machine topology;
3. how an API job becomes a multi-node scheduler job and how its files return;
4. why infrastructure, workload packaging, and validation live in different
   modules; and
5. which files and tests a new workload must add.

The fastest proof that the topology works is:

```console
$ just nxc-test mpi-hello
```

That command builds a fresh VM composition, waits for all shared services and
SLURM daemons, launches two MPI ranks, checks their output, and tears down the
test driver. It does not require a separately running deployment.
