# E2E Development Notes

The repository has two validation paths for each workload. The NXC test runs
inside the generated topology; the host E2E enters through ebservice and
ebuffer, drives a runtime worker, and reaches the frontend through local SSH
forwarding. Their application logic is separate, but both select the same
`openqcd` or `mpi-hello` composition key.

## Validation follows the repository layers

`composition.nix` is only an infrastructure factory. `compositions.nix` joins
the module named in `software/default.nix` with the identically named plug-in
from `e2e/nxc/default.nix`. Evaluation fails if the software and NXC-test
catalog keys differ.

`e2e/nxc/common.nix` waits for ebuffer, ebservice, login, the SLURM controller,
and both compute daemons. Each app-specific NXC plug-in then stages its own
fixture on shared `/users`, confirms its executable is present and the other
catalog workload is absent, submits its two-node batch job, and validates the
result.

The pinned NXC VM driver's SSH process accepts only one command per machine
during `nxc start -t`; a second call tries to reuse an already-communicated
Python subprocess. The shared test therefore performs each role's retry loop
inside one shell command, and each app uses one frontend command. Workload
execution and detailed validation remain in the maintained batch scripts, not
in a long sequence of driver stages. The E2E catalog refreshes those managed
SSH subprocesses once at the end because NXC unconditionally sends a final
`sync` command after the embedded test. The same finalizer clears NXC's HTTP
daemon flag: six nodes enable it automatically, but the local VM path never
creates the daemon that cleanup otherwise tries to stop.

The host path uses `e2e/common.py` for the shared API, RemoteManager, SLURM,
ebuffer transfer, timeout, diagnostics, and cleanup lifecycle. Application
modules export small contracts:

- `mpi_hello_e2e.py` has no input file, returns `mpi-hello.out`, and requires
  ranks 0 and 1 on two distinct compute hosts;
- `openqcd_e2e.py` uploads `openqcd-ym1.in`, returns `openqcd-e2e.log`, and
  checks the lattice, process grid, trajectory, configuration export, and
  plaquette.

`minimal-e2e.py` is the catalog dispatcher used by `scripts/run-e2e.sh`; it
does not implement another workload lifecycle. App-specific resource requests
live in `mpi-hello-job.ini` and `openqcd-job.ini`, while
`minimal-hpc.ini` remains the shared connection configuration.

## RemoteManager needs an FHS-shaped environment

RemoteManager invokes `/bin/bash` directly in some fallback command paths.
NixOS intentionally has no `/bin/bash`, so `just test [workload]` runs inside
the `e2e-fhs` environment defined in `flake.nix`. It contains Bash, SSH,
rsync, uv, and the basic tools needed by the test.

Ideally RemoteManager would resolve Bash from `PATH`, accept an executable
path, or avoid shell fallbacks. Failed commands can leave randomly named
eight-hex-digit `.sh` files and `remotemanager.log` behind. The launcher runs
from `e2e/` so those artifacts do not pollute the repository root.

## VM ports and workload switching

NXC records VM IDs and roles in `deploy/openqcd::vm.json` or
`deploy/mpi-hello::vm.json`, but allocated host SSH ports are recovered by
inspecting QEMU command lines. `scripts/tunnel.sh` matches the VM ID encoded in
the MAC address and extracts its `hostfwd` port. This works for the current NXC
VM flavour but depends on its implementation details.

Both compositions expose services on the same loopback ports: ebuffer on
8000, ebservice on 8001, and frontend SSH on 2222. Only one composition can be
tunneled at a time. The script records the active deployment below
`/tmp/nxc-exa-atow-tunnels-$UID`; when another workload is selected it closes
this repository's existing SSH control masters before creating the new
forwards. Re-running the same selection reuses healthy masters.

The tunnel and E2E launcher use `NXC_IDENTITY_FILE`, defaulting to
`~/.ssh/id_rsa`. Host-key verification is disabled because these VMs are
disposable and their keys change after rebuilds. These choices are acceptable
for a local test, not a real remote cluster.

## The host E2E supplies a RemoteExecutor adapter

The upstream HPC configuration does not model a logical remote host reached
through a local forwarded port with a chosen SSH key. Configuring
`127.0.0.1` as the host also makes RemoteManager classify it as local
execution and skip SSH.

`TunnelRemoteExecutor` in `e2e/common.py` therefore uses the logical
`nxc-frontend` host while overriding SSH to connect to `127.0.0.1:2222` with
the selected identity and noninteractive host-key options.

The upstream `write_file` sends a heredoc through nested local and SSH shells.
Generated scheduler syntax can then be interpreted during transfer instead of
when SLURM runs it. The adapter base64-encodes scheduler scripts locally and
decodes them on the frontend, which is adequate for these small text files.

## Ebuffer files bypass the upstream SCP helper

The upstream remote input and output helpers use the logical hostname directly
for SCP, which the developer host cannot resolve. The common lifecycle instead
uses the working SSH command channel:

- OpenQCD input bytes are fetched from ebuffer and written into the remote job
  directory as base64; MPI hello declares no input ebuffer.
- Both contracts read their output as base64 over SSH, decode it locally, and
  fill the output ebuffer through the API.

This shortcut is suitable for `openqcd-ym1.in` and the small text results. A
real deployment should fix routing or use a transport appropriate for large
scientific datasets.

## Scheduler handling is intentionally local

The common host job submits with the configured `sbatch --parsable`, polls
`scontrol`, writes each observed state to the scheduler ebuffer, recognizes
terminal states and exit codes, honors client cancellation, and enforces the
configured deadline. Available batch and application logs are attached to
scheduler failure diagnostics. Success, failure, and cancellation paths remove
the remote per-job directory after terminal state is confirmed; a directory is
retained only when cancellation or cleanup cannot be confirmed safely.

This is more reliable than a blocking `sbatch --wait`, but it remains a small
local monitor rather than the upstream template's full `squeue`/accounting
path. The app-specific NXC tests deliberately use direct `sbatch --wait`
because they validate the topology internally rather than the host API
lifecycle.

## OpenQCD fixes geometry at build time

The locked overlay supplies OpenQCD 2.0 with `ym1` compiled for a `2x1x1x1`
process grid. Every invocation therefore uses exactly two MPI ranks. The
software module retains that grid but changes the local lattice from
`8x8x8x8` to OpenQCD's valid `4x4x4x4` minimum. With two ranks in the first
dimension, the reported global lattice is `8x4x4x4`.

The maintained input performs one HMC trajectory using a single-step leapfrog
integrator with measurement output disabled. Tests validate stable scientific
structure and a finite plaquette rather than a CPU-specific golden
floating-point value. They also verify that the exported configuration exists,
although only the log is returned through the host output ebuffer.

## QEMU uses the host CPU model

With NXC's default QEMU CPU, MPI ranks crashed during UCX initialization with
`SIGILL`. The nixpkgs OpenMPI/UCX build expects CPU instructions absent from
QEMU's baseline model. VM `up` and `nxc-test` commands default `QEMU_OPTS` to
`-cpu host` so those instructions are visible.

This improves fidelity on the current Linux/KVM development host but reduces
portability.

## Standalone VM stop is missing upstream

The pinned NXC `stop` command calls `cleanup()` on the selected flavour, but
its `VmFlavour` does not implement that method. Consequently,
`just down vm [workload]` raises an attribute error instead of stopping the
foreground VM driver. Stop VM deployments with Ctrl-C in the terminal running
`just up`; `just down` remains valid for implemented cleanup paths such as the
Docker flavour.
