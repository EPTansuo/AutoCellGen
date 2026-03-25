# AutoCellGen

AutoCellGen is a standard cell layout generator that encompasses netlist, transistor placement, routing, and GDS flow. As a standalone executable, it can be used to generate a standard cell library.



## Csyn-fp (netlist to transistor placement)

Csyn-fp generates transistor placements from cell netlists. As a standalone executable, it can convert netlist files (.cdl / .sp files) into transistor placements.

This program is based on the content of the following paper.

Baek, Kyeonghyeon, and Taewhan Kim. "Simultaneous transistor folding and placement in standard cell layout synthesis." *2021 IEEE/ACM International Conference On Computer Aided Design (ICCAD)*. IEEE, 2021.



## Build

The current build flow is based on `MAKE/PLACE_ROUTE/csyn_fp`.

### Prerequisites

The flow expects a recent C++ toolchain, Java, Conda, and the Cadence tools used by the optional Liberty flow:

```
cmake    3.22+
gcc/g++  8.4+
Z3       4.8.11
java     1.8+
conda    ~/miniconda3
```

Environment activation is machine-specific and must be configured locally by the user. A typical local `env.sh` may activate Conda and export compiler and license variables, but this file is intentionally not tracked by git.

The Liberty flow also depends on local technology/model inputs that are not tracked by git. Populate these paths yourself as needed:

```text
./MAKE/POST_CELL_GEN/inputs/PROBE.pm
./MAKE/POST_CELL_GEN/inputs/lvs.pvl
./MAKE/POST_CELL_GEN/inputs/stdqrc
```

### One-time setup

After preparing your local environment, run these commands from the repository root. `source ./env.sh` is only an example; any equivalent environment activation is fine.

```bash
source ./env.sh
git submodule update --init --recursive
cd MAKE/PLACE_ROUTE/csyn_fp/z3
cmake -S . -B build
cmake --build build -j4
cd ..
cmake -S . -B build
cmake --build build -j4
```

After that, the placement executable is available at:

```text
./MAKE/PLACE_ROUTE/csyn_fp/build/placement
```





## Run

### Placement setup

Placement and routing options are controlled by:

```text
./DATA/input/placement_file.style
```

Each option is documented inline in that file.

### Generate placement, route, and GDS

After activating your locally configured environment. `source ./env.sh` is only an example; any equivalent environment activation is fine.

```bash
source ./env.sh
cd MAKE/PLACE_ROUTE
./1.run_csyn_fp /path/to/your_netlist.cdl
```

You can also use the provided ASAP7 example:

```bash
./1.run_csyn_fp ../../DATA/input/asap7sc7p5t.sp
```

Outputs are written to:

```text
./MAKE/PLACE_ROUTE/output/placement
./MAKE/PLACE_ROUTE/output/route
./MAKE/PLACE_ROUTE/output/gds
./MAKE/PLACE_ROUTE/output/IOnet
./MAKE/PLACE_ROUTE/output/summary.txt
```

The placement text format is:

```text
-------- Solution 0 --------
[Column 1]
NMOS : ${NMOS_name}(${fin_number}) [${source_net} ${gate_net} ${drain_net}], PMOS : ${PMOS_name}(${fin_number}) [${source_net} ${gate_net} ${drain_net}]
...
```

### Generate Liberty

The repository now includes a minimal `PostCellGen` flow under:

```text
./MAKE/POST_CELL_GEN
```

It supports two practical modes:

1. Fast schematic-based characterization.
2. Full post-layout characterization with `LVS -> PEX -> Quantus -> Liberate`.

The current default behavior is the fast path:

- DRC disabled
- LVS skipped
- Pegasus PEX skipped
- Quantus skipped
- characterization uses schematic/CDL
- small 2x2 characterization tables for quick smoke runs

Run it like this:

```bash
source ./env.sh
MAKE/POST_CELL_GEN/run.sh \
  --cell A2O1A1Ixp33_ASAP7_75t_R_w6_0 \
  --gds ./MAKE/PLACE_ROUTE/output/gds/A2O1A1Ixp33_ASAP7_75t_R_w6_0.gds \
  --cdl ./DATA/input/smoke_A2O1A1Ixp33.sp \
  --lib-name mylib
```

The generated liberty is written to:

```text
./MAKE/POST_CELL_GEN/results/lib/${lib_name}_${process}_${vdd}_${temp}_nldm.lib
```

To enable the more complete post-layout path, explicitly override the defaults:

```bash
MAKE/POST_CELL_GEN/run.sh \
  --cell ... \
  --gds ... \
  --cdl ... \
  --lib-name ... \
  --skip-lvs 0 \
  --skip-pvspex 0 \
  --skip-qtspex 0 \
  --char-from pex \
  --smoke-char 0
```

### Notes

- `env.sh` is expected to be a local, user-maintained file. It is not committed to this repository.
- `source ./env.sh` in the examples can be replaced with any equivalent environment activation method.
- Your local environment must provide the Cadence tool licenses required by `pegasus`, `quantus`, and `liberate`.
- `MAKE/POST_CELL_GEN/inputs` is intentionally local. The required tech/model files are not committed to this repository.
- The fast default liberty mode is intended for quick validation and rough synthesis/timing use, not signoff accuracy.
- Post-layout PEX characterization may still require extra convergence tuning on some cells.
- Multi-output cells are supported by the current fast Liberty flow. A validated example is `FAx1_ASAP7_75t_R`, which produces a Liberty cell with both `CON` and `SN` outputs.





## Authors

- SNUCAD, Seoul National University
- Kyeonghyeon Baek, Sehyeon Chung, Handong Cho, Hyunbae Seo, Kyu-myung Choi, Taewhan Kim
