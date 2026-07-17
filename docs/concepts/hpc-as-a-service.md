# The HPC-as-a-Service mental model

> the next section runs a little long. It lays out the core ideas
> behind the HPC-as-a-Service model
> I heavily paraphrased it from Laurent Morin's ebuffer paper, *"HPC Software as a Service: A Flexible Approach to
> Data Logistics"*.

<p align="center" style="padding: 30px 0px" >
  <img src="../figs/EB-DDF.png" >
</p>

Traditional HPC users start from a shell, a batch script, and a command such
as `sbatch`. A service-facing workflow starts somewhere else: a client
describes a computation and attaches data without ever speaking directly to
the scheduler. This page explains the mental model behind that shift, and how
it maps onto the ebuffer/ebservice/SLURM stack this repository actually runs.

## Facilities stay independent systems

A cross-facility scientific workflow spans data centers and HPC centers that
are each operated and managed independently: different administrators,
different accounts, different security policies, different maintenance
windows. Treating that collection as a single distributed system would
require a common authority no single facility is willing to grant. Treating
it instead as a *system of systems* keeps two properties intact for every
participating facility:

- **Operational independence**: each facility keeps running its own workload
  and serving its own users, with or without the cross-facility workflow.
- **Managerial independence**: each facility keeps its own administration,
  accounts, and accountability chain; no other facility acquires the right to
  act on its behalf.

The API layer described below exists to let facilities *cooperate* without
surrendering either property. That is why the design favors narrow,
self-contained services over a shared scheduler or a shared identity that
would blur who is responsible for what.

## Two building blocks: buffers and services

Two abstractions carry that cooperation:

- **Ephemeral Buffers (ebuffer)** move a bounded amount of data between
  parties for a bounded amount of time, without ever handing the client
  standing storage credentials on a facility it does not manage.
- **Application Services (ebservice)** publish a computation as a
  micro-service, independently of who eventually executes it. A maintainer
  with resource quota on a facility declares a *runtime* willing to execute
  jobs of a given type; a client then submits *jobs* against that type
  rather than against a specific machine.

This repository's `ebuffer` and `ebservice` roles are concrete, minimal
implementations of those two abstractions, scoped to one facility instead of
a federation of them. See [Ebuffer and Ebservice](../stack/ebuffer.md) for
their full properties and how this repository exposes them.

## Job pull, not job push

A client never submits directly to a scheduler it does not own. Instead:

1. The client registers a job against a micro-service.
2. A runtime controlled by the facility's own maintainer polls the service
   for compatible work.
3. Only that runtime, using its own credentials, turns the job into a
   scheduler submission.

The scheduling facility's administrator therefore stays the sole party able
to act on its own systems, and every job remains attributable to the
maintainer who chose to pull and run it. In this repository, the host-local
`RuntimeService` plays that role: it polls ebservice for compatible work,
connects to the frontend over SSH with its own key, and only then calls
`sbatch`. See [Control, data, and execution flows](../architecture/flows.md)
for the exact sequence.



## What this repository demonstrates, and what it does not

This repository runs the control/data-plane split above on a single trusted
host against one local composition; it does not implement a federation, a
global identity provider, or cross-facility data transfer.
