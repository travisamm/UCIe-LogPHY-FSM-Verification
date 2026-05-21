# UCIe UVM Verification Environment

This directory contains the SystemVerilog UVM verification environments for
the UCIe logical PHY training RTL. It is scoped to the Cadence Xcelium UVM
flows under `uvm/`; the repository root README covers the wider Chisel and RTL
project.

The UVM environment verifies training logic at several levels:

| Suite | DUT | Testbench top | Main Make target |
| --- | --- | --- | --- |
| SBINIT | `SBInitSM.sv` | `tb/logphy_tb_top.sv` | `make sbinit` |
| MBINIT | `MBInitSM.sv`, requester, responder | `tb/mbinit_tb_top.sv` | `make mbinit` |
| MBTRAIN | `MBTrainSM.sv` | `tb/mbtrain_tb_top.sv` | `make mbtrain` |
| LTSM | `LinkTrainingSM.sv` with a fused sideband partner | `ltsm/tb/ltsm_tb_top.sv` | `make ltsm` |

The suite-specific testbenches let tests target individual training state
machines without always simulating the full logical PHY. The LTSM testbench
exercises a fused path when behavior spans embedded MBINIT and the sideband
TRAINERROR handshake.

## Prerequisites

Run the flows from an environment with Cadence Xcelium and IMC available at the
paths used by `Makefile`. If you are not running on UC Berkeley EECS EDA servers,
you will have to edit the paths used by `Makefile`.

```make
XRUN := /share/instsww/cadence/XCELIUM2509/tools/bin/xrun
IMC  := ... /share/instsww/cadence/VMANAGER2509/tools/bin/imc
```

The DUT SystemVerilog sources are generated from the Chisel RTL and are read
from `../elab/generatedVerilog/logphy/`. Pre-elaborated files are checked into
the repository, but regenerate them from the repository root after RTL changes:

```bash
./generate_logphy_sv.sh
```

That elaboration flow requires `sbt` on `PATH` and Java 17 or newer. Do not
hand-edit generated files under `elab/generatedVerilog/logphy/`.

## Quick Start

Change into the UVM directory before invoking the Makefile:

```bash
cd uvm
```

Run one smoke test per suite:

```bash
make sbinit SBTEST=test_sbinit_sanity
make mbinit MBTEST=test_mbinit_sanity
make mbtrain MBTRAINTEST=test_mbtrain_sanity
make ltsm LTSTEST=test_ltsm_mbinit_repairval_trainerror
```

Default single-test targets are available for SBINIT and MBINIT:

```bash
make sbinit
make mbinit
```

`make mbtrain` is a regression target when `MBTRAINTEST` is not set. It runs
the test list defined by `MBTRAIN_TESTS` in `Makefile` and writes per-test logs
under `run_logs/mbtrain/`.

## Running Tests

### Single Tests

Select a UVM test class with the suite-specific Make variable:

```bash
make sbinit SBTEST=test_sbinit_early_req
make mbinit MBTEST=test_mbinit_repairclk
make mbtrain MBTRAINTEST=test_mbtrain_rxclkcal
make ltsm LTSTEST=test_ltsm_mbinit_repairval_trainerror
```

The available test classes live in:

- `tests/sbinit_tests.sv`
- `tests/mbinit_tests.sv`
- `tests/mbtrain_tests.sv`
- `ltsm/tests/ltsm_tests.sv`

### Regressions and Focused Runs

Use the Makefile regression targets for the maintained suite lists:

```bash
make sbinit_all
make mbinit_all
make mbtrain
```

Equivalent aliases are also present:

```bash
make sbinit_regress
make mbinit_regress
make mbtrain_regress
```

MBINIT has a focused lane repair/reversal smoke group:

```bash
make mbinit_lr03_lr04
```

PatternWriter has a standalone non-UVM PERLANEID test:

```bash
make patternwriter_lr02
```

To override a regression list without editing the Makefile, pass the relevant
test list on the command line:

```bash
make mbinit_all MBINIT_TESTS="test_mbinit_param_only test_mbinit_cal"
make mbtrain MBTRAIN_TESTS="test_mbtrain_valvref test_mbtrain_datavref"
```

### Logs and Pass/Fail Reporting

The regression targets collect logs and a summary file below `run_logs/`:

```text
run_logs/
|-- sbinit/
|-- mbinit/
`-- mbtrain/
```

Regression pass/fail detection checks both simulator exit status and log
content. A test is reported as failed if Xcelium exits nonzero or its log
contains UVM error/fatal or Xcelium error patterns. Inspect the per-test log
and the suite `.results` file after a failure.

SBINIT, MBINIT, and LTSM single-test targets invoke Xcelium directly. Their
simulator output remains in the normal Xcelium working files and terminal output
unless redirected by the caller. MBTRAIN always uses its log-collecting wrapper,
including when `MBTRAINTEST` selects one test.

## Coverage

SBINIT and MBINIT coverage targets run the maintained test lists, merge IMC
coverage data, and emit HTML reports:

```bash
make cov_sbinit
make cov_mbinit
```

The report entry points are:

```text
cov_work/sbinit/report/index.html
cov_work/mbinit/report/index.html
```

Override the output directory when needed:

```bash
make cov_sbinit COV_SBINIT_WORK=my_sbinit_cov
make cov_mbinit COV_MBINIT_WORK=my_mbinit_cov
```

`open_imc.sh` is available for opening merged IMC data or generated reports on
systems where the GUI and browser setup support it.

Remove generated simulation and coverage artifacts with:

```bash
make clean
```

## Architecture

### Directory Layout

The UVM environment follows a layered structure:

```text
uvm/
|-- agent/       drivers, monitors, sequencers, transactions, agent packages
|-- env/         environments, scoreboards, virtual-sequencer/config classes
|-- if/          SystemVerilog interfaces for sideband and mainband pins
|-- seq/         suite sequences and sequence packages
|-- tb/          suite testbench tops, binds, SVA, standalone TBs
|-- tests/       suite UVM tests and test packages
|-- ltsm/        fused LinkTrainingSM interfaces, TB, and tests
|-- coverage/    coverage sources and coverage configuration
|-- Makefile     Xcelium compile/run, regression, coverage, and cleanup flows
`-- logphy_requirements.csv
```

Each suite compiles its packages explicitly from `Makefile`. The package files
pull in the suite components, while testbench tops instantiate the DUT,
interfaces, and UVM config-db connections needed by the tests.

### Suite Model

SBINIT, MBINIT, and MBTRAIN each use the same verification pattern:

1. A test configures expectations on the environment or scoreboard.
2. A sequence drives the DUT partner behavior through an agent.
3. Monitors observe protocol and control interfaces.
4. Scoreboards gate checks to the substate or requirement group under test.
5. Assertions in `tb/logphy_sva.sv` add protocol and structural checks where
   the bound DUT hierarchy supports them.

The RTL training FSMs split protocol responsibilities into requester and
responder roles. The UVM tests usually drive the non-DUT partner role needed to
move the DUT through a selected exchange.

### Training Flow Under Test

At the logical PHY level, training proceeds through:

```text
RESET -> SBINIT -> MBINIT -> MBTRAIN -> LINKINIT -> ACTIVE
```

MBINIT covers parameter negotiation, calibration, clock repair, valid repair,
lane reversal, lane repair, and the transition toward MBTRAIN. MBTRAIN covers
Vref, speed-idle, calibration, validation, deskew, and link-speed substates.
Error paths can route to TRAINERROR; when that behavior depends on full LTSM
sideband traffic, use the fused LTSM suite rather than an isolated sub-FSM test.

### Interfaces and Checks

Important interfaces in this directory include:

- `if/sb_ctrl_if.sv`, `if/sb_req_if.sv`, and `if/sb_rsp_if.sv` for SBINIT
  sideband control and packet exchange.
- `if/logphy_if.sv` for shared logical PHY observation and drive signals.
- `if/mbinit_if.sv` for MBINIT sideband, FSM control, pattern, repair, and
  lane-control visibility.
- `if/mbtrain_if.sv` for MBTRAIN control and training observation.
- `ltsm/if/ltsm_obs_if.sv` for fused LinkTrainingSM observation and partner
  stimulus.

Scoreboards live in `env/` and expose expectation flags used by focused tests,
for example full-flow checks, Vref checks, RXCLKCAL checks, data-center checks,
lane repair checks, and FSM done/error expectations. Prefer adding targeted
expectations and sequences for focused requirements instead of making every
test require a full training pass.

SVA sources live in `tb/logphy_sva.sv`. The `mbinit_state_sync_sva` assertion
is intentionally excluded from coverage reporting because its current state
timing is too strict for the RTL. PatternWriter and related assertions bind when
their matching modules appear in the DUT hierarchy.

## Current Notes 05/20/2026 - commit fcf649e

- `SBINIT_TESTS` currently includes `test_sbinit_req_backpressure`. The test
  file documents that this case is expected to fail until the SBInit requester
  keeps its Out-of-Reset payload stable while ready is back-pressured.
- Some MBINIT tests intentionally disable `fsmCtrl_done` expectations while
  checking requester progress, message traffic, repair behavior, or error paths
  that are observable in the isolated MBINIT testbench.
- For MBINIT RM-05 repair debug logging, add:

  ```bash
  make mbinit MBTEST=test_mbinit_rm05_post_repair_persist \
    MBINIT_XRUN_EXTRA='+define+MBINIT_RM05_DEBUG'
  ```

See `../docs/verification_plan.md` and `logphy_requirements.csv` for
requirement-level verification tracking.

## Extending the Environment

When adding coverage for a requirement:

1. Add or extend an interface only when the DUT signal is not already exposed.
2. Put reusable stimulus in `seq/` and keep the test class responsible for
   selecting expectations and the scenario.
3. Add driver, monitor, scoreboard, or SVA checks at the lowest layer that can
   observe the behavior reliably.
4. Include the test in the relevant `*_TESTS` Makefile list when it should run
   in the maintained regression.
5. Regenerate RTL before debugging UVM failures caused by Chisel changes.
