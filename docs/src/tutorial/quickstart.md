# Quick start

The repository ships one composition, `openqcd`: ebuffer, ebservice, a SLURM
frontend and controller, and the two compute nodes the OpenQCD `ym1` job needs.
It is the default for every recipe.

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
$ just build
$ QEMU_OPTS="-cpu host" nix develop --command nxc start \
    --identity-file "$HOME/.ssh/id_ed25519.pub" \
    -C "openqcd::vm"

# terminal 2
$ NXC_IDENTITY_FILE="$HOME/.ssh/id_ed25519" just test
```

## 1. Run the self-contained topology test

```console
$ just nxc-test
```

This command:

1. builds `openqcd::vm`;
2. boots a temporary six-node topology;
3. waits for both APIs, the SLURM controller, and both compute daemons;
4. stages the OpenQCD input under shared `/users`;
5. submits the two-node `ym1` job; and
6. checks that its log and configuration output are non-empty.

It does not require `just up` in another terminal.

## 2. Run the complete service path

First install the host E2E dependencies if you have not already:

```console
$ just install
```

In terminal 1, build and start the VM deployment:

```console
$ just up
```

Keep that foreground process running. In terminal 2:

```console
$ just test
```

`just test` establishes the three tunnels automatically. The OpenQCD contract
uploads `openqcd-ym1.in`, launches exactly two MPI ranks, downloads
`openqcd-e2e.log`, and validates its lattice, process grid, single trajectory,
configuration export, and plaquette.

Return to terminal 1 and press Ctrl-C to stop the VM deployment.

> `just down` does not stop VMs: NXC's VM flavour has no standalone cleanup.
> Ctrl-C on the foreground `just up` process is the supported local stop path.

## 3. Declare your own cluster

A composition is an entry in `compositions.nix`. Compute nodes come in groups
of identical nodes: a group `compute` with `count = 4` becomes `compute1` to
`compute4`, and its `node` enables the apps every node in it runs. For example,
four OpenQCD nodes plus one node that also has MPI Hello:

```nix
openqcd-mixed = topology {
  frontend.exa-atow.apps.openqcd = {
    enable = true;
    testFixtures = true;
  };
  computeGroups = {
    compute = {
      count = 4;
      node.exa-atow.apps.openqcd.enable = true;
    };
    mixed = {
      count = 1;
      node.exa-atow.apps = {
        openqcd.enable = true;
        mpi-hello.enable = true;
      };
    };
  };
  testScript = openqcdTest.testScript;
};
```

Then run it like the default:

```console
$ just nxc-test openqcd-mixed
$ just up vm openqcd-mixed
```

Each compute node advertises the apps it enables as SLURM features, so jobs can
target them with `srun --constraint=mpi-hello ...`. The module system checks the
declaration: a misspelled option, a zero count, or a group name containing
digits fails at evaluation with a message naming it.
