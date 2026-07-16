# Plugging Scientific Software into the HPC-as-a-Service Stack

This guide uses the repository's OpenQCD 2.0 `ym1` workload as a concrete
example for integrating your own scientific application. The goal is to make
the application available on the compute nodes, describe it to ebservice, run
it through SLURM, and move its input and output files through ebuffer.

The repository separates integration into three layers:

1. **Shared infrastructure:** `composition.nix` builds the ebuffer, ebservice,
   shared-storage, and SLURM roles from injected workload and test modules. It
   contains no application policy.
2. **Workload software:** `software/default.nix` catalogs the NixOS module to
   install for each composition name.
3. **Validation:** `e2e/nxc/` supplies common readiness plus app-specific NXC
   tests, while `e2e/common.py` runs app contracts through the shared host-side
   API, SSH, scheduler, transfer, and cleanup lifecycle.

`compositions.nix` joins the software and NXC-test catalogs and requires their
keys to match. The maintained keys are `openqcd` and `mpi-hello`; `openqcd` is
the command-line and flake default. Keep application packages in `software/`
and application contracts in app-specific E2E modules rather than adding them
to the shared infrastructure or lifecycle code.

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

The maintained OpenQCD E2E has this deliberately small contract:

| Kind | Name | Purpose |
| --- | --- | --- |
| Input ebuffer | `openqcd-ym1.in` | Configure one small HMC trajectory |
| Output ebuffer | `openqcd-e2e.log` | Return the scientific run log |

It has no scalar arguments. The runtime stages the maintained
`e2e/openqcd-ym1.in`, launches `ym1`, and returns only the log; transient or
large binary configuration data is outside this topology smoke test.

The `mpi-hello` contract has no input ebuffer. It returns `mpi-hello.out` and
checks that ranks 0 and 1 ran on two distinct compute hosts. It is useful as a
fast topology diagnostic before integrating a larger application.

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

The current flake follows that pattern for both maintained workloads.
`software/mpi-hello.nix` compiles the small C source with OpenMPI.
`software/openqcd.nix` exposes the locked overlay package's `app/ym1`
executable as `bin/ym1`, composes OpenMPI, and reduces OpenQCD's compile-time
local lattice to the valid `4x4x4x4` minimum without changing its two-rank
process grid. No upstream OpenQCD source is copied into this repository.

Register the module in the software catalog. The key is the public workload
and NXC composition name:

```nix
{
  mpi-hello = ./mpi-hello.nix;
  my-solver = ./my-solver.nix;
  openqcd = ./openqcd.nix;
}
```

The selected module is installed consistently on the frontend and compute
roles; unselected workload executables are absent. Do not install workload
software on ebuffer or ebservice.

Add a matching `e2e/nxc/my-solver.nix` plug-in and catalog entry. The NXC
plug-in provides a frontend fixture module and app-specific assertions; common
service, login, controller, and compute readiness comes from
`e2e/nxc/common.nix`. A missing or extra catalog key makes composition
evaluation fail instead of silently building an untested workload.

For the host E2E, create `e2e/my_solver_e2e.py` exporting an
`E2EApplication`. Its contract selects the job INI, input and output names,
scheduler core, diagnostics, timeout, and scientific validation. Register it
in the `APPLICATIONS` mapping in `e2e/minimal-e2e.py`; keep connection,
polling, transfer, diagnostics, and cleanup behavior in `e2e/common.py`.

Build before touching the API layer:

```bash
just check
just build vm my-solver
```

After starting the topology, confirm the executable is visible from the
frontend and under SLURM:

```bash
just up vm my-solver
just tunnel my-solver
ssh -p 2222 root@localhost 'command -v my-solver'
```

Also submit a direct batch job first. This isolates packaging, shared-storage,
and scheduler problems from API problems.

For a checkout on storage visible to the SLURM nodes, submit the example that
matches the running composition:

```bash
# With the OpenQCD composition:
sbatch examples/openqcd-ym1.sbatch

# With the MPI hello composition:
sbatch examples/mpi-hello.sbatch
```

The OpenQCD script accepts another input path as its first argument. That input
must retain the `openqcd-e2e` run name if the example's final log check should
use the same output filename.

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
import shlex

from ebsclient import RuntimeJobError
from ebstemplate.scheduler import JobSchedulerTemplate


class MySolverJob(JobSchedulerTemplate):
    def get_scheduler_core(self) -> str:
        try:
            iterations = int(self.job.arguments[0])
        except (TypeError, ValueError) as error:
            raise RuntimeJobError("iterations must be an integer") from error
        if not 1 <= iterations <= 100_000:
            raise RuntimeJobError("iterations must be between 1 and 100000")

        input_file = shlex.quote(str(self.job_dir / "model.in"))
        output_file = shlex.quote(str(self.job_dir / "result.dat"))
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

The runtime needs one HPC INI and one app-specific job INI. Start from the
shared `e2e/minimal-hpc.ini` and either `e2e/openqcd-job.ini` or
`e2e/mpi-hello-job.ini`.

The HPC file defines the scheduler profile, SSH target, command names, and
timeouts. The job file defines application directories and SLURM resources:

```ini
[JOB]
job_name = my-solver

[INSTALLATION]
app_name = my-solver
app_dir = /run/current-system/sw/bin
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
their own resource profile instead of copying these development values. For
the shipped OpenQCD 2.0 build, `tasks = 2` is not just a resource preference:
it must match the executable's compile-time `2x1x1x1` process grid. The example
places one of those ranks on each compute node.

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

For local VM development, review `e2e/common.py` and the two maintained
contracts, `e2e/mpi_hello_e2e.py` and `e2e/openqcd_e2e.py`.
`minimal-e2e.py` only validates the selected catalog name and dispatches its
contract. The common module contains narrowly scoped compatibility code for
NXC's forwarded SSH port and NixOS's lack of `/bin/bash`. Keep those
workarounds out of application contracts. A real deployment should use its
normal reachable HPC hostname and SSH configuration.

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

Copy the structure of an app-specific contract, not the shared lifecycle or
its compatibility workarounds. A useful application E2E should verify:

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

The OpenQCD contract uploads its input through an input ebuffer and downloads
`openqcd-e2e.log` through an output ebuffer. It checks the local and global
lattices, the two-rank process grid, exactly one completed trajectory,
configuration export, and a finite plaquette without relying on a
CPU-specific golden value. The MPI hello contract downloads `mpi-hello.out`
and verifies exactly two ranks and two distinct compute hosts.

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

The default workload is OpenQCD. The flavour is the first optional argument to
`build`, `up`, and `down`; the workload is second:

```bash
just install
just up                         # openqcd::vm
just up vm mpi-hello            # mpi-hello::vm
```

Run only one of those deployments for a given host E2E. In another terminal,
select the matching contract:

```bash
just test                       # OpenQCD
just test mpi-hello
```

The in-topology tests do not require a separately running deployment:

```bash
just nxc-test
just nxc-test mpi-hello
```

When finished with a VM, return to the terminal running `just up` and press
Ctrl-C. The pinned NXC release has no standalone `VmFlavour.cleanup()` method,
so `just down vm ...` currently fails. Flavours that implement cleanup can use
the recipe normally:

```bash
just down docker
just down docker mpi-hello
```

`just tunnel [workload]` and `just test [workload]` use fixed localhost ports
8000, 8001, and 2222. Only one composition can be exposed at a time; selecting
the other workload automatically closes this repository's managed SSH masters
and establishes tunnels to the requested deployment.

The shipped E2E remains intentionally small. Read
[the development notes](DevNotes.md) before using its compatibility shortcuts
as a design for a production service.
