# Quick start

Start with `mpi-hello`. It is fast, has no input file, and proves the same
two-node scheduler/MPI path used by OpenQCD.

## 0. Install the requirements

The supported VM workflow expects:

- an x86-64 Linux host;
- Nix with the `nix-command` and `flakes` features enabled;
- [Just](https://just.systems/man/en/), a command runner similar to Make; and
- an SSH key pair used to connect to the disposable local VMs.

The topology starts six QEMU VMs. The host must have enough memory for the
guests and the Nix build, and access to KVM is strongly recommended.

### Install and configure Nix

Follow the [official Nix installation
instructions](https://nixos.org/download/). On a Linux host with systemd, the
recommended multi-user installation is:

```console
$ curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --daemon
```

Open a new shell after installation, then enable the features used by this
repository:

```console
$ mkdir -p ~/.config/nix
$ echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

See the [Nix flakes documentation](https://nix.dev/concepts/flakes.html) for
other ways to enable these features.

### Install Just

Just stores project commands, called recipes, in the root `justfile`. It is
similar to Make, but is a command runner rather than a build system. Install it
with Nix:

```console
$ nix profile install nixpkgs#just
$ just --version
```

The [Just installation
documentation](https://just.systems/man/en/packages.html) lists alternatives
for other package managers. NXC, uv, jq, and the other project tools do not
need separate host installations: the pinned versions are supplied by
`nix develop` when a Just recipe needs them.

### Create the local VM SSH key

The pinned NXC VM backend reads `~/.ssh/id_rsa.pub` when it starts a topology
and adds that public key to the local VMs. The tunnel and host E2E then use the
matching private key at `~/.ssh/id_rsa`. These keys are for the disposable
local VMs; they are not Grid'5000 credentials.

If this key pair does not already exist in the environment running NXC, create
one:

```console
$ mkdir -p ~/.ssh
$ chmod 700 ~/.ssh
$ ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
```

The tunnel and E2E scripts accept a different private key through
`NXC_IDENTITY_FILE`, but it must match the public key injected when NXC starts
the VMs. The current `just up` and `just nxc-test` recipes rely on NXC's
default `~/.ssh/id_rsa.pub` startup location.

To use another key pair, build first and invoke `nxc start` with its public key
instead of using `just up`:

```console
# terminal 1
$ just build vm mpi-hello
$ QEMU_OPTS="-cpu host" nix develop --command nxc start \
    --identity-file "$HOME/.ssh/id_ed25519.pub" \
    -C "mpi-hello::vm"

# terminal 2
$ NXC_IDENTITY_FILE="$HOME/.ssh/id_ed25519" just test mpi-hello
```

## 1. Run the self-contained topology test

```console
$ just nxc-test mpi-hello
```

This command:

1. builds `mpi-hello::vm`;
2. boots a temporary six-node topology;
3. waits for both APIs, the SLURM controller, and both compute daemons;
4. stages the example under shared `/users`;
5. verifies `mpi-hello` is installed and `ym1` is absent;
6. submits the two-node job; and
7. checks that its output is non-empty.

It does not require `just up` in another terminal.

## 2. Run the complete service path

First install the host E2E dependencies if you have not already:

```console
$ just install
```

In terminal 1, build and start the matching VM deployment:

```console
$ just up vm mpi-hello
```

Keep that foreground process running. In terminal 2:

```console
$ just test mpi-hello
```

`just test` establishes the three tunnels automatically. A successful run
prints changing pipeline states, an E2E success line, the SLURM job ID,
scheduler and output ebuffer IDs, and the returned rank lines. The host
validator requires ranks 0 and 1 to name two different compute hosts.

Return to terminal 1 and press Ctrl-C to stop the VM deployment.

> Do not use `just down vm mpi-hello` for this pinned NXC release. Its VM
> flavour lacks the standalone cleanup method used by `nxc stop`; Ctrl-C on
> the foreground `just up` process is the supported local stop path.

## 3. Try the scientific workload

Repeat the same two validation layers for OpenQCD:

```console
$ just nxc-test openqcd
```

Then, in terminal 1:

```console
$ just up vm openqcd
```

And in terminal 2:

```console
$ just test openqcd
```

The OpenQCD contract uploads `openqcd-ym1.in`, launches exactly two MPI ranks,
downloads `openqcd-e2e.log`, and validates its lattice, process grid, single
trajectory, configuration export, and plaquette.

Because `openqcd` and `vm` are the defaults, the last workflow can also be
written:

```console
$ just nxc-test
$ just up
# in another terminal
$ just test
```

## 4. Run both applications in one composition

The combined composition installs both software modules on the frontend and
compute nodes. Its NXC test submits both jobs:

```console
$ just nxc-test multi-software-composition
```

For host-side validation, keep the combined deployment running and select the
application contract with the second `just test` argument:

```console
# terminal 1
$ just up vm multi-software-composition

# terminal 2
$ just test multi-software-composition mpi-hello
$ just test multi-software-composition openqcd
```
