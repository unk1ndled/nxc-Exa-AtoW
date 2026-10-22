# Packages

Nix flake packaging the full LOFAR radio-interferometry imaging stack:
DDFacet, killMS, and ddf-pipeline.

> This version targets the `HackathonRennes` branch of ddf-pipeline
> [(source)](https://github.com/mhardcastle/ddf-pipeline/tree/HackathonRennes),
> replicating its uv install script as a reproducible Nix build.

## Custom packages

The following packages are not available in nixpkgs and are defined locally under `pkgs/`:

| Package | Description |
|---|---|
| `ddfacet` | DDFacet imager (direction-dependent calibration) |
| `kill-ms` | killMS direction-dependent calibration solver |
| `ddf-pipeline` | End-to-end LOFAR HBA imaging pipeline |
| `python-casacore` | Python bindings for casacore |
| `casacore` | Radio astronomy data processing library |
| `lofar-beam` | LOFAR beam model library |
| `dysco` | |

ddfacet version relaxation
| search | replacement |
|---|---|
| `"numpy >= 1.15.1, <= 1.22.4; python_version >= '3.10'"` | `"numpy >= 1.15.1"` |
| `"numpy >= 1.15.1, <= 1.22.4; python_version >= '3.8' and python_version < '3.10'"` | `"numpy >= 1.15.1"` |
| `"numpy >= 1.15.1, <= 1.26; python_version >= '3.10'"` | `"numpy >= 1.15.1"` |
| `'cython<=0.29.30'` | `'cython'` |
| `"Cython >= 0.25.2, <= 0.29.30"` | `"cython"` |

## Nixpkgs dependencies

The rest of the dependency chain is sourced from `nixos-unstable`:
`astropy`, `numpy`, `scipy`, `dask`, `pandas`, `matplotlib`,
`cython`, `pybind11`, `pyfftw`, `numexpr`, `psutil`, and others.

Compatibility overrides are applied only inside the DDFacet Python package set.
They never replace global packages such as `python3`, `git`, `protobuf`, or
`redis`, so unrelated Exa-AToW packages retain the normal Nixpkgs dependency
graph.

## Usage

```bash
nix build .#ddf-pipeline
```

The DDFacet stack has a private Python 3.12 scope for legacy compatibility.
