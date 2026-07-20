# Run, debug, and adapt the workload

The package and both test contracts are now registered. This final chapter
runs the complete user-facing path, explains the expected evidence, and gives
you a checklist for adapting the example to a real application.

## 8. Run the complete path

First run the self-contained NXC validation if you have not already:

```console
$ just nxc-test mpi-calculator
```

Then start a persistent matching deployment:

```console
$ just up vm mpi-calculator
```

Leave it running. In a second terminal, launch the host test:

```console
$ just test mpi-calculator
```

The tunnel helper forwards ebuffer on port 8000, ebservice on port 8001, and
frontend SSH on port 2222. The test should finish with output resembling:

```text
E2E passed: API -> runtime -> two-node SLURM -> MPI calculator
19 + 23 = 42 across compute1, compute2
Scheduler job:     1
Scheduler ebuffer: <uuid> (COMPLETED, exit 0:0)
Output ebuffer:    <uuid> (<size> bytes)
Returned mpi-calculator.out:
rank 0 operand 19 on compute1
rank 1 operand 23 on compute2
result add = 42
```

Job IDs, UUIDs, output sizes, and the mapping of ranks to compute host names
will vary. The important facts are a successful terminal SLURM record, the
result 42, ranks 0 and 1, and two distinct hosts.

Return to the first terminal and press Ctrl-C to stop the VM deployment. For
the pinned NXC version, the VM flavour does not implement the standalone
cleanup used by `just down`; Ctrl-C is the supported local path.

## 9. Debug the first failures

The two test layers fail at different boundaries, and that is useful. Start
with the first failing layer instead of debugging the whole service path at
once.

| Symptom | Likely cause and first place to look |
| --- | --- |
| Flake evaluation reports different software and E2E names | The keys in `software/default.nix` and `e2e/nxc/default.nix` are not identical. Check spelling and kebab-case. |
| `command -v mpi-calculator` fails | The package is not in `environment.systemPackages`, or the catalog points to the wrong module. |
| The NXC test finds `mpi-hello` or `ym1` | The workload module was imported into shared `composition.nix` instead of being selected through the software catalog. |
| The SLURM job stays pending | The request exceeds the VM resources, or a compute daemon is not ready. Inspect `squeue`, `scontrol show job <id>`, and `sinfo` on the frontend. |
| `srun` reports an MPI or PMIx error | Confirm `--mpi=pmix`, the `openmpi.nix` import, and the default `QEMU_OPTS=-cpu host` path. |
| SLURM completes but the host E2E cannot return output | `output_name`, the path written by `scheduler_core`, and `diagnostic_files` must use the same filename. |
| The host validator sees only one host | Check `nodes = 2`, `tasks = 2`, and `--ntasks-per-node=1` in every resource declaration. |
| The host E2E cannot connect or tests the wrong binary | Only one deployment can own ports 8000, 8001, and 2222. Keep a matching `just up vm mpi-calculator` running and rerun `just test mpi-calculator`. |

On a host-E2E failure, read the diagnostics printed before cleanup. The shared
lifecycle tails the main SLURM output and error files plus every filename in
`diagnostic_files`. Adding the application's own log there is often the
fastest way to turn a generic pipeline failure into a useful scientific error.

## 10. Review the change as a workload contract

Before committing, the new workload should have all of these files and
registrations:

| Concern | Required change |
| --- | --- |
| Source | `software/mpi-calculator.c` |
| Nix package and runtime | `software/mpi-calculator.nix` |
| Composition catalog | `mpi-calculator` in `software/default.nix` |
| Direct scheduler example | `examples/mpi-calculator.sbatch` |
| NXC fixture and assertions | `e2e/nxc/mpi-calculator.nix` |
| NXC test catalog | `mpi-calculator` in `e2e/nxc/default.nix` |
| Existing composition isolation | Negative calculator check in the other NXC tests |
| Host resource contract | `e2e/mpi-calculator-job.ini` |
| Host behavior contract | `e2e/mpi_calculator_e2e.py` |
| Host dispatcher | Import and entry in `e2e/minimal-e2e.py` |

Finish with:

```console
$ just check
$ just nxc-test mpi-calculator
# with `just up vm mpi-calculator` active in another terminal
$ just test mpi-calculator
```

If the change affects shared MPI configuration, SLURM resources, shared
storage, tunnels, the API services, or `e2e/common.py`, also run both existing
workloads when practical. Shared infrastructure can pass the calculator while
breaking a file-heavy scientific application such as OpenQCD.

## When your real application is larger

The calculator keeps source beside its Nix module, which is convenient for a
small demonstrator. A real application can instead use a pinned Nix package,
an overlay package, or a derivation that fetches a released source archive.
Keep the same boundary: package and runtime settings belong under `software/`,
not in the shared composition factory.

Likewise, replace the fixed operands with representative input files and
validate scientific meaning rather than only process exit status. Good E2E
assertions answer questions a user cares about: Was the intended problem
loaded? Did every required rank participate? Did the solver converge? Is the
returned value finite and within its physical range? Was the expected output
artifact actually returned through the API?

That is the reusable pattern demonstrated here: package the application,
prove it inside the topology, then prove the complete user-facing service
path with an application-specific contract.
