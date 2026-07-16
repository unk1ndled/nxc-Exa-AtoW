# Plugging Scientific Software into the HPC-as-a-Service Stack

This guide explains how to replace the tiny `mpi-hello` workload with your own
scientific application. The goal is to make the application available on the
compute nodes, describe it to ebservice, run it through SLURM, and move its
input and output files through ebuffer.

The integration has two distinct parts:

1. **Cluster installation:** package the executable with Nix and install it on
   the frontend and compute nodes.
2. **Service integration:** describe the application inputs and outputs, then
   implement the small scheduler adapter that builds its SLURM command.

Keep those parts separate. Application packages belong in `software/`; API and
workflow code belongs in your own client/runtime project or, for a local proof
of concept, under `e2e/`.

## 1. Decide the application contract

Before writing code, list everything a run consumes and produces. For example,
suppose an application is normally invoked as:

```bash
solver --iterations 500 --input model.in --output result.dat
```

Its service contract could be:

| Kind | Name | Example |
| --- | --- | --- |
| Argument | `iterations` | `500` |
| Input ebuffer | `model.in` | Uploaded configuration file |
| Output ebuffer | `result.dat` | Downloadable result file |

Use arguments for small scalar values and ebuffers for files or binary data.
Every name is positional: the runtime receives values in the same order used
by `argument_names`, `ebin_names`, and `ebout_names`.

## 2. Package the application with Nix

Create a lowercase kebab-case module such as `software/my-solver.nix`:

```nix
{ pkgs, ... }:
let
  mySolver = pkgs.stdenv.mkDerivation {
    pname = "my-solver";
    version = "1.0";
    src = ./my-solver-src;

    nativeBuildInputs = [ pkgs.cmake ];
    buildInputs = [ pkgs.openmpi ];

    installPhase = ''
      runHook preInstall
      install -Dm755 my-solver "$out/bin/my-solver"
      runHook postInstall
    '';
  };
in
{
  environment.systemPackages = [ mySolver ];
}
```

This is only a skeleton. Adapt `src`, the build system, libraries, and install
phase to the real project. Prefer an existing nixpkgs package when one exists:

```nix
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.gromacs ];
}
```

Import the module from `software/default.nix`:

```nix
{
  imports = [
    ./openmpi.nix
    ./my-solver.nix
  ];
}
```

Modules imported there are installed consistently on the frontend and compute
roles. Do not install workload software on ebuffer or ebservice.

Build before touching the API layer:

```bash
just check
just build
```

After starting the topology, confirm the executable is visible from the
frontend and under SLURM:

```bash
just up
just tunnel
ssh -p 2222 root@localhost 'command -v my-solver'
```

Also submit a direct batch job first. This isolates packaging, shared-storage,
and scheduler problems from API problems.

## 3. Describe the microservice

The microservice tells ebservice what users must provide and what they can
download. Using `ebsclient`:

```python
microservice = api.mservices.create(
    {
        "name": "my-solver",
        "mime_type": "application/x-my-solver",
        "code": "",
        "argument_names": ["iterations"],
        "result_names": [],
        "ebin_names": ["model.in"],
        "ebout_names": ["result.dat"],
        "runtime_uuid": "",
        "policy_uid": "",
        "tags": ["template::slurm"],
    }
)
```

The MIME type connects the microservice to a compatible runtime. Give each
application family a stable, unique MIME type.

## 4. Register a compatible runtime

The runtime represents the worker that can execute this application:

```python
runtime = api.runtimes.create(
    {
        "name": "my-solver-slurm",
        "accepted_mime_type": "application/x-my-solver",
        "policy_uid": "",
        "tags": ["template::slurm"],
    }
)
```

ebservice associates pending jobs with runtimes through this accepted MIME
type. A runtime is not the scientific executable itself; it is the service
process that polls ebservice and translates jobs into scheduler work.

## 5. Implement the scheduler job adapter

Subclass `JobSchedulerTemplate`. For many applications, the only required
method is `get_scheduler_core()`:

```python
from ebstemplate.scheduler import JobSchedulerTemplate


class MySolverJob(JobSchedulerTemplate):
    def get_scheduler_core(self) -> str:
        iterations = self.job.arguments[0]
        input_file = self.job_dir / "model.in"
        output_file = self.job_dir / "result.dat"
        return (
            f"srun my-solver "
            f"--iterations {iterations} "
            f"--input {input_file} "
            f"--output {output_file}"
        )
```

The scheduler template performs the surrounding workflow:

1. creates a per-job directory;
2. fetches input ebuffers using the names in `ebin_names`;
3. generates and submits the scheduler script;
4. waits for or monitors the scheduler job;
5. uploads files named by `ebout_names` into their output ebuffers;
6. updates the job status in ebservice.

Treat every API argument as untrusted input. Validate types and ranges and use
safe quoting when values enter shell commands. For more complicated setup,
override `preprocess()` to generate configuration files or prepare the run
directory. Override input/output hooks only when the standard file mapping is
insufficient.

## 6. Configure the HPC connection and job resources

The runtime needs one HPC INI and one job INI. Start from
`e2e/minimal-hpc.ini` and `e2e/minimal-job.ini`.

The HPC file defines the scheduler profile, SSH target, command names, and
timeouts. The job file defines application directories and SLURM resources:

```ini
[JOB]
job_name = my-solver

[INSTALLATION]
app_name = my-solver
app_dir = /users/user1
run_dir = /users/user1

[RESOURCES]
partition = main
nodes = 2
tasks = 2
cpus_per_task = 1
time = 00:10:00

[MODULES]
module_purge = false
modules =
```

The local VMs currently expose one SLURM CPU and 900 MB per compute node. Do
not request more than the topology declares. Real deployments should provide
their own resource profile instead of copying these development values.

## 7. Start the runtime worker

Connect the registered runtime to the adapter:

```python
from ebsclient import RuntimeService

service = RuntimeService(
    runtime=runtime,
    RuntimeJobType=MySolverJob,
    hpc_config="my-solver-hpc.ini",
    job_config="my-solver-job.ini",
    polltime=2,
    keep_going=False,
    max_workers=1,
)
service.start()
```

For local VM development, review `e2e/minimal-e2e.py`. It contains narrowly
scoped compatibility code for NXC's forwarded SSH port and NixOS's lack of
`/bin/bash`. Keep those workarounds out of reusable scientific application
logic. A real deployment should use its normal reachable HPC hostname and SSH
configuration.

## 8. Submit from the client side

The client template creates the input and output ebuffers and submits the job:

```python
from ebstemplate.scheduler import ClientSchedulerTemplate

client = ClientSchedulerTemplate(api, microservice.uuid)
client.set_inputs(
    args=["500"],
    ebin_files=["./model.in"],
)
client.submit()
client.monitoring()
client.download_data("./results")
```

After completion, `./results/result.dat` came back through the output ebuffer.
Do not consider the integration complete merely because SLURM reports success:
download the output and validate its contents, format, or checksum.

## 9. Turn the example into a real test

Copy the structure of `e2e/minimal-e2e.py`, not necessarily all its
workarounds. A useful application E2E should verify:

- authentication succeeds;
- the microservice and runtime are registered;
- every declared input ebuffer is created and consumed;
- the scheduler job runs on the expected resources;
- every declared output ebuffer is filled;
- the client downloads and validates meaningful scientific output;
- jobs, buffers, runtimes, and microservices are cleaned up on success or
  failure;
- polling has a finite timeout.

Use unique tags and names for tests so leaked resources can be identified and
removed safely.

## Recommended development order

When something fails, debug it from the bottom up:

1. **Package:** does the executable run on one compute VM?
2. **SLURM:** does a handwritten `sbatch` job complete?
3. **Shared files:** can frontend and compute nodes see the same job directory?
4. **Runtime:** does the worker pick up a pending API job?
5. **Inputs:** do input ebuffers arrive under the expected filenames?
6. **Outputs:** are result files uploaded and downloadable?
7. **Scientific validation:** is the returned result actually correct?

This order avoids debugging Nix, SLURM, SSH, API registration, and application
behavior at the same time.

## Local workflow

```bash
just install
just up
```

In another terminal:

```bash
just test
```

When finished:

```bash
just down
```

The shipped E2E remains intentionally small. Read [Notes.md](Notes.md) before
using its compatibility shortcuts as a design for a production service.
