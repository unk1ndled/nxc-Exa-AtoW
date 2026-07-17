# The HPC-as-a-Service mental model

Traditional HPC users often begin with a shell, a batch script, and a command
such as `sbatch`. A service-facing workflow begins somewhere else: a client
describes a computation and attaches data without needing to speak directly to
the scheduler.

This repository keeps those two views connected but separate.

## The five objects to keep apart

| Object | Responsibility | In this repository |
| --- | --- | --- |
| Microservice | Declares an application-facing contract: MIME type, input names, and output names. | Created in `e2e/common.py`. |
| Runtime | Advertises that a worker can execute a compatible MIME type. | A host-side `RuntimeService`. |
| Pipeline job | One API request bound to concrete input and output buffers. | Submitted by the E2E client. |
| Scheduler job | One allocation and batch execution on the cluster. | Submitted with `sbatch`, observed with `scontrol`. |
| Scientific process | The actual MPI executable. | `mpi-hello` or OpenQCD's `ym1`. |

A runtime is not the scientific executable. It is the adapter that accepts a
service job, prepares a scheduler script, stages data, submits to SLURM, and
reports the outcome.

## Control plane and data plane

The **control plane** carries descriptions and state:

```text
client -> ebservice -> runtime -> SLURM controller -> slurmd
```

The **data plane** carries files:

```text
client <-> ebuffer <-> runtime <-> /users job directory <-> compute ranks
```



## Why keep the scheduler?

Wrapping an application in an API does not replace the facility scheduler.
SLURM still owns admission, placement, resource limits, task launch, job
state, and cancellation. The service adapter turns an application-level
request into a scheduler-native request.

That separation lets each layer speak its natural language:

- the client speaks application inputs and outputs;
- the runtime speaks service objects, SSH, files, and scheduler commands;
- SLURM speaks nodes, tasks, CPUs, partitions, and states; and
- the application speaks its own command-line and scientific file formats.
