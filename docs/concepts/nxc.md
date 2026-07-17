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
you can find a comprehensive tutorial [here]() that you can spend a saturday afternoon playing with. But for the ease of getting started, here are a few quickstart guides:


composition 
nxc build
nxc start
