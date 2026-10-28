# Web client

An optional Exa-AToW client: a React site whose notebook pages run Python in
short-lived, sandboxed Jupyter containers. Notebook code reaches the platform
through `ebsclient`, exactly like any other client; nothing in `cluster/` or
`pkgs/` knows about it.

* [`webapp/`](webapp/README.md): React + Vite frontend (landing page,
  experimenter notebook, maintainer notebook).
* [`server/`](server/README.md): FastAPI notebook server that starts the
  Docker kernels and an allow-list egress proxy.

## Run it against a local deployment

Needs Docker on the host; everything else comes from the dev shell.

```bash
just up            # terminal 1: start the openqcd topology
just web-install   # once
just web-dev       # terminal 2: tunnels + webapp (:5173) + server (:9000)
```

`just web-dev` forwards the ebuffer (8000) and ebservice (8001) APIs to the
Docker bridge gateway (`TUNNEL_BIND_ADDRESS` in `scripts/tunnel.sh`). Kernels
reach them as `host.docker.internal`, through the egress proxy, which is the
only route out of their internal network.

The host firewall must accept those two ports from Docker. On NixOS:

```nix
networking.firewall.interfaces.docker0.allowedTCPPorts = [ 8000 8001 ];
```

## Known limitations

* The kernels, the proxy, and the VMs must share one physical host, since the
  APIs are only reachable through the host's Docker bridge.
* The server executes arbitrary code for anyone holding a token; see the
  security note in [`server/README.md`](server/README.md).
