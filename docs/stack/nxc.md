# NixOS-Compose

<p align="center">
  <img src="../figs/nxc.png" >
</p>



<div  style="display: flex; flex-direction: row; gap: 1rem ; ">
    <div>
        <p>NixOS-compose will be the cornerstone of our deployment strategy, since it allows us to leverage the nix ecosystem while writing declarative configuration.  </p> 
        <p>Another key advantage is the fact that it allows us to write configuration once and deploy it across multiple flavors: the same declarative NixOS role descriptions can be realized as Docker containers, QEMU virtual machines, or other backends such as Vagrant and Kameleon images. This repository relies on the Docker and VM flavors so we can iterate quickly on a laptop before touching a shared cluster. That same composition can then be deployed either locally, for fast and disposable testing, or on a real testbed such as Grid'5000, so the reproducible local cluster built here doubles as a rehearsal for deployment on genuine HPC infrastructure.
        </p>
    </div>
  <img src="../figs/NXC.drawio.svg" >
</div>

## Get started with nxc
You can find a comprehensive tutorial [here](https://nixos-compose.gitlabpages.inria.fr/tuto-nxc/01_intro.html) that you can spend a saturday afternoon playing with. But for the ease of getting started, here are the three concepts you need to get moving:

- **composition**: a named combination of a workload (`openqcd`, `mpi-hello`, ...) and a flavor (`vm`, `docker`, ...), written as `<workload>::<flavour>`. In this repository, `compositions.nix` and `nxc.json` declare which compositions exist and which flavor is the default.
- **`nxc build -C <composition>`**: evaluates and builds every role of the selected composition, producing a store path under `build/<composition>`.
- **`nxc start -C <composition>`**: deploys the built composition (booting VMs or starting containers, depending on the flavor) and records its metadata under `deploy/<composition>.json`.

For example, building and starting the OpenQCD workload as VMs looks like:

```console
$ nxc build -C openqcd::vm
$ nxc start -C openqcd::vm
```

This repository wraps both steps (plus the `QEMU_OPTS` and workload defaults it needs) behind `just build` and `just up`; see the [command reference](../reference/commands.md) for the full recipe list.
