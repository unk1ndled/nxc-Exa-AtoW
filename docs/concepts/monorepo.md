# Repository architecture

This repository is organized around three Nix concepts: modules provide
capabilities, profiles compose them into named systems, and checks provide
evidence that those systems behave as declared.

## Repository map

```text
.
├── flake.nix                         Pins dependencies and exposes NXC builds
├── nxc.json                          Selects the profile-generated catalog
│
├── nix/
│   ├── modules/applications/         Reusable application NixOS modules
│   ├── profiles/default.nix          Composition names, placement, and checks
│   └── lib/
│       ├── mk-compositions.nix       Validates and evaluates every profile
│       └── mk-topology.nix           Shared API, storage, and SLURM roles
│
├── checks/
│   ├── nixos/
│   │   ├── with-readiness.nix        Platform readiness shared by all profiles
│   │   ├── profiles/                 Profile-specific NXC assertions
│   │   └── jobs/                     Batch fixtures executed by those checks
│   └── host/                         API-to-SLURM workflow and Python tests
│
├── config/                           Data supplied to upstream service modules
├── tools/
│   ├── host/                         Host-check launcher
│   ├── vm/                           Local VM adapters
│   └── grid5000/                     Grid'5000 adapters
└── justfile                          Stable user-facing commands
```

## Composition flow

```text
nix/modules/applications/*.nix
             │
             ▼
nix/profiles/default.nix ────── checks/nixos/profiles/*.nix
             │                         │
             └──────────┬──────────────┘
                        ▼
            nix/lib/mk-compositions.nix
                        │
                        ▼
              nix/lib/mk-topology.nix
                        │
                        ▼
             <profile>::<NXC flavour>
```

A profile is the only public composition declaration. Uniform profiles select
`modules`; heterogeneous profiles select `frontendModules` and explicit
`computeNodes`. Every profile declares its `check` in the same attribute set,
so module placement cannot drift away from its validation catalog.

The shared topology enables the ebuffer and ebservice modules exported by the
locked `exaAtowPkgs` input. This repository supplies deployment values and
configuration data; it does not duplicate upstream service lifecycle logic.
