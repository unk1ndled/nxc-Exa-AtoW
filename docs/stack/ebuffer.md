# Ebuffer and Ebservice

Ebuffer and ebservice are the two API services behind the **data plane** and
**control plane** described in [the HPC-as-a-Service mental
model](../concepts/hpc-as-a-service.md). Ebuffer moves bytes; ebservice moves
descriptions and state. Neither replaces SLURM: the runtime worker is what
turns their objects into an actual scheduler job.

## Ebuffer: the data plane

Ephemeral Buffers (ebuffer) are a bounded, temporary, API-visible envelope
used to move bytes into or out of a facility without ever handing the client
standing credentials on that facility's storage.

### Properties

- **Size limit**: each buffer has a maximum size fixed by the service
  configuration, not chosen by the client.
- **Time-limited lifetime**: once a buffer's lifetime expires it is destroyed
  without notice, so nothing lingers past its useful life.
- **Unique identifier**: a buffer is addressed by a UID, never by a path or
  hostname on the target facility.
- **Access-control metadata**: only the holder of the right token/ACL entry
  can read or write a given buffer.

Together these properties decouple *who is allowed to send data* from *who
can reach the storage system*: a client only ever needs a buffer UID and a
token, never a login, key, or mount on a facility it does not manage.

### Where it sits in the pipeline

```text
client <-> ebuffer <-> runtime <-> /users job directory <-> compute ranks
```

The runtime worker is the only party that ever moves bytes between an ebuffer
and the shared `/users` job directory. See [Control, data, and execution
flows](../architecture/flows.md) for the exact sequence.

Do not confuse an ebuffer with `/users`:

- ebuffer is the API-visible, ephemeral envelope used *before and after* the
  scheduler job runs;
- `/users` is POSIX shared storage mounted by the frontend and compute nodes
  *while* the scheduler job runs.

The runtime bridges the two: it materializes ebuffer bytes into a per-job
directory under `/users`, then uploads a result from that directory into an
output buffer.

### Ebuffer in this repository

Each composition runs one `ebuffer` role, reachable at
`http://127.0.0.1:8000/api/v1` once tunneled (see the [command
reference](../reference/commands.md)). Buffers are stored in memory for the
lifetime of the deployment, a deliberate development shortcut rather than a
production durability guarantee.

Both workloads use ebuffer the same way:

- an **input buffer** carries the job's input file (for example
  `openqcd-ym1.in`) from the client to the runtime;
- an **output buffer** carries the application's result back to the client,
  separate from the scheduler-status buffer that tracks job state.

## Ebservice: the control plane

Application Services (ebservice) publish a computation as a micro-service,
independently of who eventually executes it. A maintainer with resource
quota on a facility declares a *runtime* willing to execute jobs of a given
type; a client then submits *jobs* against that type rather than against a
specific machine or account.

### Objects it holds

- **Microservice**: a declared application contract with a MIME type and
  ordered argument, input-buffer, and output-buffer names. It is a
  declaration, not a running daemon.
- **Runtime**: a worker-side registration advertising an accepted MIME type.
  In this repository, the host-local `RuntimeService` is that runtime.
- **Pipeline job**: the service-level job a client submits against a
  microservice, tied to its input, output, and scheduler-status buffers.

### Job pull, not job push

A client never submits directly to a scheduler it does not own:

1. The client registers a job against a micro-service.
2. A runtime controlled by the facility's own maintainer polls ebservice for
   compatible work.
3. Only that runtime, using its own credentials, turns the job into a
   scheduler submission.

This keeps the scheduling facility's administrator as the sole party able to
act on its own systems, and keeps every job attributable to the maintainer
who chose to pull and run it.

### Where it sits in the pipeline

```text
client -> ebservice -> runtime -> SLURM controller -> slurmd
```

### Ebservice in this repository

Each composition runs one `ebservice` role, reachable at
`http://127.0.0.1:8001/api/v1` once tunneled. The host-local `RuntimeService`
polls it for compatible pipeline jobs, connects to the frontend over SSH with
its own key, submits with `sbatch --parsable`, and mirrors observed scheduler
state into a status ebuffer as it polls `scontrol show job`. See [Control,
data, and execution flows](../architecture/flows.md) for the full sequence,
including cleanup.
