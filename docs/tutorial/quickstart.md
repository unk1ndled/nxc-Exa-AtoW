# Quick start

Start with `mpi-hello`. It is fast, has no input file, and proves the same
two-node scheduler/MPI path used by OpenQCD.

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
