# E2E Notes
Noting down Hacks and cut corners that had to be done for the e2e test 


## RemoteManager needs an FHS-shaped environment

RemoteManager invokes `/bin/bash` directly in some fallback command paths.
NixOS intentionally has no `/bin/bash`, so the first E2E attempt failed before
it could contact the frontend. The `e2e-fhs` environment in `flake.nix` creates
a small FHS-compatible shell containing Bash, SSH, rsync, uv, and basic tools.

Ideally RemoteManager would resolve Bash from `PATH`, accept an executable path, or avoid shell fallbacks.

Failed RemoteManager commands can also leave randomly named eight-hex-digit
`.sh` files and `remotemanager.log` behind. They are ignored, and the E2E runs
from `examples/` to keep any such artifacts out of the repository root.

## VM ports are discovered by scraping QEMU processes

claasic nxc tunneling thing 


NXC records VM IDs and roles in `deploy/hpc::vm.json`, but the allocated host
SSH ports are recovered by inspecting the QEMU command lines. The tunnel script
matches the VM ID encoded in the MAC address and extracts the corresponding
`hostfwd` port.

That works for the current NXC VM flavour, but it depends on implementation
details

Host-key verification is disabled because these VMs are disposable and their
host keys change after rebuilds. That is acceptable for this local test and
not acceptable for a real remote cluster.


## The E2E supplies its own RemoteExecutor adapter

The upstream HPC configuration does not model the combination we need here: a
logical remote host reached through a local forwarded port with a chosen SSH
key. Using `127.0.0.1` as the configured host does not work because
RemoteManager classifies all `127.*` addresses as local execution and skips
SSH entirely.

`TunnelRemoteExecutor` therefore constructs the RemoteManager `URL` itself:

- logical host: `nxc-frontend`, so RemoteManager considers it remote;
- actual host: `127.0.0.1`, injected with SSH's `HostName` option;
- port: 2222;
- identity: `NXC_IDENTITY_FILE`, defaulting to `~/.ssh/id_rsa`;
- noninteractive host-key options for disposable VMs.



## Script transfer uses base64 instead of the upstream heredoc

The upstream `write_file` sends a heredoc through nested local and SSH shells.
The generated scheduler script contains command substitutions such as
`$(srun ...)`; nested quoting caused those commands to execute while the file
was being transferred instead of when SLURM ran it.

The E2E adapter base64-encodes the scheduler script locally and decodes it on
the frontend. It is safe enough for a small text script and avoids another
round of nested quoting. It is not intended as a high-performance file
transfer mechanism.

## Output transfer bypasses the upstream SCP helper

The upstream SCP transport uses the logical hostname directly and fails, to resolve `nxc-frontend` on the host.

For this tiny output, `MinimalMpiJob.eboutput` reads `mpi-hello.out` over the
working command channel as base64, decodes it locally, and fills the output
ebuffer through the API. 

## Scheduler handling is intentionally minimal

The normal scheduler template submits asynchronously and monitors scheduler
state. The minimal job overrides `execute` and uses `sbatch --wait` instead.


## QEMU uses the host CPU model

With NXC's default QEMU CPU, both MPI ranks crashed in UCX initialization with
`SIGILL` before reaching `main()`. The nixpkgs OpenMPI/UCX build expects CPU
instructions absent from QEMU's baseline model. `just up` defaults
`QEMU_OPTS` to `-cpu host` so those instructions are visible.

This improves fidelity on my Linux/KVM host but reduces portability.


