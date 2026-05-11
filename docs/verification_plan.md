# UCIe LogPHY Verification Plan
**UCIe Spec Rev 3.0**

## 1. Overview

This document defines the verification plan for the UCIe LogPHY layer implementation (see [ucb-bar/ucie](https://github.com/ucb-bar/ucie) and active `dev-verification` work). It lists mandatory requirements from **UCIe Specification Rev 3.0** that must be verified through simulation, organized by LTSM state and cross-cutting concerns.

## 1.1 Checklist legend

The **Done** column uses task-list style checkboxes. It reflects what exists **today** in automated checks (UVM under `uvm/`, Chisel/Scala tests under `scala/test/`). It is **not** full spec sign-off.

| Mark | Meaning |
|------|---------|
| `[X]` | **Done** — directed test runs via `make` / `./mill test` and scoreboard or Scala assertions meaningfully cover the requirement. |
| `[~]` | **Partial** — RTL + some harness or scoreboard hooks, or only a **subset** checked (often sideband-only, no mainband/pattern proof). |
| `[ ]` | **Not done** — no automated test found; RTL may still exist. |

Same tokens work in GitHub-style lists, e.g. `- [X] SB-01 …` (optional; §4 uses tables only).

**Evidence** names UVM tests (`make sbinit` / `make mbinit` / `make mbtrain` from `uvm/`), Scala tests, or scoreboards.

### Automation snapshot (May 2026 tree)

Rough counts: **each requirement ID** in §4 is one row (~**140** total). `[~]` MBINIT rows are mostly **sideband + sub-state handshakes / `fsm_done`** in `mbinit_scoreboard`, not pattern length, mainband, or repair error paths.

| Mark | Count |
|------|------:|
| `[X]` | **15** |
| `[~]` | **34** |
| `[ ]` | **~91** |

**UVM inventory**

- **SBINIT:** `sbinit_regress` — `test_sbinit_sanity`, `test_sbinit_timeout`, `test_sbinit_partner_not_ready`, `test_sbinit_early_req`, `test_sbinit_multiple_reqs` (`uvm/Makefile`, `logphy_sbinit_tests.sv`, `logphy_scoreboard.sv`).
- **MBINIT:** `mbinit_regress` — `test_mbinit_sanity`, `test_mbinit_param_only`, `test_mbinit_param_mismatch` (`mbinit_tests.sv`, `mbinit_scoreboard.sv`). **PatternWriter LR-02:** `make patternwriter_lr02` (`tb/patternwriter_tb_lr02.sv`) — PERLANEID burst vs generated `PatternWriter.sv` (no RTL change).
- **MBTRAIN:** `mbtrain_regress` — `test_mbtrain_sanity` runs `seq_mbtrain_full` through all 12 sub-states (`mbtrain_tests.sv`, `mbtrain_base_test.sv`, `mbtrain_scoreboard.sv`). Scoreboard: sideband REQ decode + `fsm_done` + **`mbLaneCtrlIo` per-state checks (XC-05)** via `check_lane_ctrl()`. TC-01 (Tx tri-state in TXSELFCAL) fully checked; VV-02 and RCC-02 partially checked (tri-state proxy, not driven-low proof).
- **MBINIT scoreboard additions:** `check_lane_ctrl()` added for all 7 MBINIT states (XC-05); `check_pattern_type()` added for REPAIRCLK/REPAIRVAL/REVERSALMB/REPAIRMB (RC-02, RV-03, LR-02, RM-01). `mbLaneCtrlIo` fully wired in `mbinit_if` and `mbinit_tb_top`; monitor captures all lane ctrl + patternWriter/Reader fields.

**Scala inventory (non-commented)**

- `RdiHandshakeIntegrationTest.scala` — adapter/RDI clock + `RDIWakeHandshakeResponder` smoke tests.
- `PhyRetrainSidebandHandshakeTest.scala` — PHY retrain encoding exchange loopback.
- `ProtocolLayerTest.scala`, `SidebandLinkSerdesTest.scala`, tilelink/phy specs — adjacent layers, not full LTSM.

**Commented / inactive (not counted as Yes)**

- `SBInitSMTest.scala`, `LinkTrainingSMTest.scala`, `ParallelGaloisLFSRTest.scala` — entire tests commented out.

## 2. RTL implementation snapshot

| Module / area | Status (high level) |
|---------------|---------------------|
| SBInit, MBInit, MBTrain FSMs | Present under `scala/src/logphy/modules/linktraining/`; sideband-heavy UVM for SBINIT + MBINIT happy/negative PARAM. |
| Top-level `LinkTrainingSM` | Large implementation present (`modules/linktraining/LinkTrainingSM.scala`); **not** covered by dedicated Scala test (file still commented). |
| `LogicalPhy`, `UcieTop`, D2D / protocol stack | Present; **not** mapped row-by-row in this checklist except where Scala tests touch adapters. |
| RDI | Expanded modules (`RDIStateMachine`, `RDIController`, etc.); Scala tests cover **narrow** handshake slices only. |

## 3. Priority definitions

- **P0 (Must Have):** Blocks basic link bringup functionality. Required for RESET-to-ACTIVE path.
- **P1 (Should Have):** Required for spec compliance and robustness, including error paths and edge cases.
- **P2 (Nice to Have):** Optional features, multi-module support, or items out of current implementation scope.

**Notes:**

- We aren't implementing any debugging features (in spec).
- For constrained-random, messages can't be random: use bit-exact encodings so the DUT can respond.

## 4. Verification requirements (checklist)

### 1. SBINIT — Sideband Initialization

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [X] | SB-01 | UCIe Module must send 64-UI clock pattern (1010...) and 32-UI low on both SB data Tx | 4.5.3.2 | P0 | Pattern gen in SBInitRequester | `test_sbinit_sanity`, `logphy_scoreboard` |
| [X] | SB-02 | UCIe Module Partner must sample incoming SB data patterns with incoming clock | 4.5.3.2 | P0 | | `test_sbinit_sanity`, `logphy_scoreboard` |
| [X] | SB-03 | On pattern detection on at least one SB data-clock Rx combo, must stop sending after completing current iteration | 4.5.3.2 | P0 | detectPatternCounter logic | `test_sbinit_sanity`, `logphy_scoreboard` |
| [X] | SB-04 | If pattern not detected, must continue alternating for total of 8ms then timeout to TRAINERROR | 4.5.3.2 | P0 | Timeout path critical | `test_sbinit_timeout`, `logphy_scoreboard` |
| [X] | SB-05 | After detection, SB Tx/Rx must be enabled for functional sideband messages | 4.5.3.2 | P0 | RAW to PACKET mode transition | `test_sbinit_sanity`, `logphy_scoreboard` |
| [X] | SB-06 | Must send {SBINIT Out of Reset} sideband message continuously until partner detection | 4.5.3.2 | P0 | | `test_sbinit_partner_not_ready`, `logphy_scoreboard` |
| [X] | SB-07 | Must send {SBINIT done req} and wait for {SBINIT done resp} before exiting to MBINIT | 4.5.3.2 | P0 | | `test_sbinit_sanity`, `logphy_scoreboard` |
| [X] | SB-08 | Module partner must ignore received {SBINIT done req} if not ready to proceed | 4.5.3.2 | P1 | | `test_sbinit_early_req`, `logphy_scoreboard` |
| [X] | SB-09 | Module partner must collapse multiple outstanding {SBINIT done req} messages into single response | 4.5.3.2 | P1 | Edge case | `test_sbinit_multiple_reqs`, `logphy_scoreboard` |

### 2. MBINIT.PARAM — Parameter Negotiation

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [X] | MP-01 | Must exchange Tx voltage swing, max data rate, clock mode, clock phase, UCIe-Sx8, SB feature extensions, Tx adjust runtime, module ID via sideband | 4.5.3.3.1 | P0 | MBInitRequester/Responder | `test_mbinit_sanity`, `test_mbinit_param_only`, `mbinit_scoreboard` |
| [X] | MP-02 | UCIe Module Partner must respond with max common data rate (min of local and remote) | 4.5.3.3.1 | P0 | localNegotiatedMaxDataRate logic | `test_mbinit_sanity`, `mbinit_scoreboard` |
| [X] | MP-03 | Clock mode in response must match the request value | 4.5.3.3.1 | P0 | interoperableParamsComparison | `test_mbinit_sanity`, `test_mbinit_param_only`, `mbinit_scoreboard` |
| [X] | MP-04 | If interoperable params not found, must escalate error | 4.5.3.3.1 | P0 | interoperableParamsErrorFlag | `test_mbinit_param_mismatch`, `mbinit_scoreboard` |
| [ ] | MP-05 | All modules in multi-module design must have same parameter values (except Module ID) | 4.5.3.3.1 | P2 | Multi-module not implemented | — |
| [X] | MP-06 | On receiving {MBINIT.PARAM configuration resp}, must exit to MBINIT.CAL | 4.5.3.3.1 | P0 | | `test_mbinit_sanity`, `mbinit_scoreboard` (`saw_state_cal`) |
| [ ] | MP-07 | MBINIT stall handling: {MBINIT.PARAM SBFE resp} with stall encoding must be sent once every 4ms | 4.5.3.3.1.2 | P1 | Stall conditions | — |
| [ ] | MP-08 | Sideband Feature Extensions (SBFE) negotiation if SB_MGMT_UP flag is set | 4.5.3.3.1.1 | P1 | | — |

### 3. MBINIT.CAL — Calibration

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [X] | MC-01 | Must send {MBINIT.CAL Done req} and wait for {MBINIT.CAL Done resp} | 4.5.3.3.2 | P0 | mbInitCalDone gates REQ in RTL | `test_mbinit_sanity`, `test_mbinit_cal` (`seq_mbinit_cal_only`: delayed `mbInitCalDone`), `mbinit_scoreboard` |
| [X] | MC-02 | On receiving {MBINIT.CAL Done resp}, must exit to MBINIT.REPAIRCLK | 4.5.3.3.2 | P0 | | `test_mbinit_sanity`, `test_mbinit_cal`, `mbinit_scoreboard` (`saw_state_repairclk`) |

### 4. MBINIT.REPAIRCLK — Clock/Track Repair

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [X] | RC-01 | Must enable Tx/Rx on Clock, Track, and redundant lanes | 4.5.3.3.3 | P0 | mbLaneCtrlIo in REPAIRCLK | `test_mbinit_sanity`, `test_mbinit_repairclk`, `mbinit_scoreboard` (`saw_repairclk_lane_ctrl_good` / XC-05) |
| [X] | RC-02 | Must send clock repair pattern and check repair success via Tx-initiated point test | 4.5.3.3.3 | P0 | Requester patternWriter CLKREPAIR + patternReader verify in RTL | `test_mbinit_sanity`, `test_mbinit_repairclk`, `mbinit_scoreboard` (`saw_repairclk_pw_clkrepair`, `saw_repairclk_pr_clkrepair`; 128-iter / TRAINERROR not isolated) |
| [X] | RC-03 | If clock/track unrepairable, must exit to TRAINERROR via handshake | 4.5.3.3.3 | P0 | Error path | `test_mbinit_repairclk_unrep`, `mbinit_scoreboard` (`expect_repairclk_rc03`: `fsmCtrl_error`, no REPAIRVAL; TRAINERROR SB not checked) |
| [ ] | RC-04 | If repair applied successfully, must verify by repeating point test | 4.5.3.3.3 | P1 | | — |
| [X] | RC-05 | On {MBINIT.REPAIRCLK done resp}, must exit to MBINIT.REPAIRVAL | 4.5.3.3.3 | P0 | | `test_mbinit_sanity`, `test_mbinit_repairclk`, RCLK DONE REQ + `saw_state_repairval` (responder DONE RESP may mux with patternReader in RTL) |

### 5. MBINIT.REPAIRVAL — Valid Lane Repair

Checklist uses **Done** = `[X]` when the listed **Evidence** is exercised in CI/regress with known gaps called out in **Notes**. **`test_mbinit_sanity`** runs **`seq_mbinit_full`** unless noted.

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [~] | RV-01 | Must set clock phase at center of data UI; partner must sample Valid with forwarded clock | 4.5.3.3.4 | P0 | MBInitSM REPAIRVAL TODO for UI centering; `PatternWriter` VALTRAIN uses forwarded clkP/clkN | `test_mbinit_sanity` + `seq_mbinit_full`, `mbinit_scoreboard` (`expect_full_mbinit` + `expect_rv01_checks`: VALTRAIN + `usingPatternWriter`; negotiated `clockPhase` ⊆ local; `usingPatternReader` in REPAIRVAL); analog / true UI centering not proven |
| [X] | RV-02 | All Data lanes must be held low during Valid repair | 4.5.3.3.4 | P0 | **Waiver:** evidence is **`mbLaneCtrlIo`** (En semantics) via XC-05, not sampled mainband data | `test_mbinit_sanity` + `seq_mbinit_full`, `mbinit_scoreboard` (`check_lane_ctrl` / `expect_lane_ctrl_checks`, REPAIRVAL `txDataEn` expectation) |
| [X] | RV-03 | Must send 128 iterations of VALTRAIN pattern (unscrambled) on VLD | 4.5.3.3.4 | P0 | **Gap:** TB checks **pattern type** VALTRAIN in REPAIRVAL; does not count **128** UI or prove scramble off (fixed in `PatternWriter` RTL) | `test_mbinit_sanity` + `seq_mbinit_full`, `mbinit_scoreboard` (`check_pattern_type` / `expect_pattern_type_checks`) |
| [ ] | RV-04 | Must repeat for RVLD (redundant valid) | 4.5.3.3.4 | P0 | | — |
| [ ] | RV-05 | If repair needed, must apply repair and verify success | 4.5.3.3.4 | P1 | | — |
| [~] | RV-06 | If repair unsuccessful or unrepairable, must exit to TRAINERROR | 4.5.3.3.4 | P0 | **`fsmCtrl_error`** on MBInit-only TB (`test_mbinit_repairval_unrep`); **fused LTSM + SB** closure: `test_ltsm_mbinit_repairval_trainerror` + `ltsm_fused_sb_partner` (REPAIRVAL fail → `TRAINERROR_ENTRY` REQ on `io_sbLaneIo_tx`, RESP on `io_sbLaneIo_rx`, `io_ltState==7`) | `test_mbinit_repairval_unrep` + `seq_mbinit_repairval_fail`; **`make ltsm`** (`test_ltsm_mbinit_repairval_trainerror`, `uvm/ltsm/tb/ltsm_tb_top.sv`) |
| [X] | RV-07 | On {MBINIT.REPAIRVAL done resp}, must exit to MBINIT.REVERSALMB | 4.5.3.3.4 | P0 | Checked via requester state + RVAL **REQ** messages in `expect_full_mbinit` | `test_mbinit_sanity` + `seq_mbinit_full`, `mbinit_scoreboard` (`saw_rval_*`, `saw_state_reversalmb`) |

### 6. MBINIT.REVERSALMB — Lane Reversal Detection

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [X] | LR-01 | Must send {MBINIT.REVERSALMB init req} and wait for resp | 4.5.3.3.5 | P0 | | `test_mbinit_sanity` + `seq_mbinit_full`, `mbinit_scoreboard` `expect_full_mbinit`: **REQ** — `REVERSALMB_INIT_REQ` on requester TX (`saw_lr_init_req_tx`). **RESP** — `REVERSALMB_INIT_RESP` decoded on **requester RX** (`saw_lr_init_resp_rx`); monitor samples `requesterSbLaneIo_rx_*` (partner / seq `MB_LR_INIT_RESP`). Responder-leg `saw_lr_init_resp_tx` remains for DUT **responder TX** only. |
| [X] | LR-02 | Must send Per Lane ID pattern on all N data lanes (128 iterations, unscrambled) | 4.5.3.3.5 | P0 | Split: MBInit vs PatternWriter | **MBInit:** `test_mbinit_sanity`, `mbinit_scoreboard` `check_pattern_type` — PERLANEID (`2'h2`) when `patternWriterIo_req_valid` in `REVERSALMB`. **PatternWriter (LR-02b):** `make patternwriter_lr02` — standalone `tb/patternwriter_tb_lr02.sv`: 64 mainband cycles (=128×16/32 serializer UI), per-lane `A0nA` duplicated words on all lanes for `functionalLanes=3'b011`, `txLfsrCtrl_increment` never asserted (no LFSR path). Other `functionalLanes` codes not covered here. |
| [ ] | LR-03 | Partner must perform per-lane compare on all N Rx lanes | 4.5.3.3.5 | P0 | PatternReader compare | — |
| [ ] | LR-04 | Must correctly detect lane reversal and apply if needed | 4.5.3.3.5 | P0 | applyLaneReversal output | — |
| [ ] | LR-05 | If x32 partner connected to x64, must recognize width difference from param exchange | 4.5.3.3.5 | P1 | interpretBy8Lane | — |
| [~] | LR-06 | On {MBINIT.REVERSALMB done resp}, must exit to MBINIT.REPAIRMB | 4.5.3.3.5 | P0 | | `mbinit_scoreboard` (`saw_state_repairmb`) |
| [ ] | LR-07 | Must exit to TRAINERROR on detection failure | 4.5.3.3.5 | P0 | Requires `applyReversalMbTxReg=1` (reversal must be detected first); driving `MB_LR_RES_RESP_FAIL` constant added but full sequence deferred | — |

### 7. MBINIT.REPAIRMB — Data Lane Repair

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [~] | RM-01 | Must send 128 iterations of Per Lane ID pattern (unscrambled) for lane testing | 4.5.3.3.6 | P0 | PatternWriter config | `test_mbinit_sanity`, `mbinit_scoreboard` (`check_pattern_type`: PERLANEID(2) in REPAIRMB; iteration count not checked) |
| [ ] | RM-02 | Rx must check pass/fail on data lanes and redundant lanes | 4.5.3.3.6 | P0 | | — |
| [ ] | RM-03 | Must apply single-lane or two-lane repair per repair resources | 4.5.3.3.6 | P1 | Repair mux chain logic | — |
| [ ] | RM-04 | Must send {MBINIT.REPAIRMB apply degrade req} with correct lane map code if width degrade needed | 4.5.3.3.6 | P1 | Width degrade negotiation | — |
| [ ] | RM-05 | If post-repair errors persist, must exit to TRAINERROR | 4.5.3.3.6 | P0 | | — |
| [ ] | RM-06 | If width changed on Tx or Rx, must repeat lane test (Step 2) | 4.5.3.3.6 | P1 | txWidthChanged/rxWidthChanged | — |
| [ ] | RM-07 | If unrepairable, must exit to TRAINERROR | 4.5.3.3.6 | P0 | | — |
| [~] | RM-08 | On {MBINIT.REPAIRMB end resp}, must exit to MBTRAIN | 4.5.3.3.6 | P0 | | `test_mbinit_sanity`, RM END + `saw_state_tombtrain`, `fsm_done` |

### 8. MBTRAIN.VALVREF — Valid Vref Training

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [ ] | VV-01 | Partner must set forwarded clock phase at center of data UI on Tx | 4.5.3.4.1 | P0 | | — |
| [~] | VV-02 | Must sample Valid with forwarded clock; all data lanes and Track held low | 4.5.3.4.1 | P0 | mbLaneCtrlIo | `test_mbtrain_sanity`, `mbtrain_scoreboard` (`check_lane_ctrl`: txDataTriState=0, txTrackTriState=0, rxValidEn=1; no driven-low proof) |
| [ ] | VV-03 | Must use 128 iterations of continuous VALTRAIN pattern (unscrambled) | 4.5.3.4.1 | P0 | | — |
| [ ] | VV-04 | Detection success if VALTRAIN errors < per-lane threshold | 4.5.3.4.1 | P0 | maxErrorThresholdPerLane | — |
| [ ] | VV-05 | LFSR RESET has no impact in this state | 4.5.3.4.1 | P1 | | — |
| [~] | VV-06 | On {MBTRAIN.VALVREF end resp}, must exit to MBTRAIN.DATAVREF | 4.5.3.4.1 | P0 | | `test_mbtrain_sanity`, `mbtrain_scoreboard` (`saw_dv_start_req`) |

### 9. MBTRAIN.DATAVREF — Data Vref Training

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [ ] | DV-01 | Must use 4K UI of continuous LFSR pattern with correct valid framing | 4.5.3.4.2 | P0 | | — |
| [ ] | DV-02 | Detection success if total error count < threshold per lane | 4.5.3.4.2 | P0 | | — |
| [~] | DV-03 | On {MBTRAIN.DATAVREF end resp}, must exit to MBTRAIN.SPEEDIDLE | 4.5.3.4.2 | P0 | | `test_mbtrain_sanity`, `mbtrain_scoreboard` (`saw_si_done_req`) |

### 10. MBTRAIN.SPEEDIDLE — Speed Transition Idle

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [ ] | SI-01 | If from DATAVREF: must transition to highest common speed | 4.5.3.4.3 | P0 | freqSel output | — |
| [ ] | SI-02 | If from L1: must restore operating speed from last ACTIVE | 4.5.3.4.3 | P0 | goToState logic | — |
| [ ] | SI-03 | If from LINKSPEED/PHYRETRAIN (speed degrade) and not 4GT/s: must pick next-lower rate | 4.5.3.4.3 | P0 | Speed degrade path | — |
| [ ] | SI-04 | Else must exit to TRAINERROR | 4.5.3.4.3 | P0 | | — |
| [ ] | SI-05 | Link width set to width from last REPAIRMB or REPAIR exit | 4.5.3.4.3 | P1 | | — |
| [~] | SI-06 | On {MBTRAIN.SPEEDIDLE done resp}, must exit to MBTRAIN.TXSELFCAL | 4.5.3.4.3 | P0 | | `test_mbtrain_sanity`, `mbtrain_scoreboard` (`saw_tc_done_req`) |

### 11. MBTRAIN.TXSELFCAL — Tx Self-Calibration

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [X] | TC-01 | Data/Clock/Valid/Track Tx are tri-stated; Rx permitted to be disabled | 4.5.3.4.4 | P0 | | `test_mbtrain_sanity`, `mbtrain_scoreboard` (`check_lane_ctrl`: txDataTriState=FFFF, txClkTriState=1, txValidTriState=1, txTrackTriState=1, rxDataEn=0, rxClkEn=0) |
| [~] | TC-02 | On {MBTRAIN.TXSELFCAL Done resp}, must exit to MBTRAIN.RXCLKCAL | 4.5.3.4.4 | P0 | | `test_mbtrain_sanity`, `mbtrain_scoreboard` (`saw_rcc_start_req`) |

### 12. MBTRAIN.RXCLKCAL — Rx Clock Calibration

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [ ] | RCC-01 | Partner must start sending forwarded clock and Track after start req received | 4.5.3.4.5 | P0 | rxClkCalSendFwClkPattern | — |
| [~] | RCC-02 | Tx clock must be free running; all data lanes and Valid held low | 4.5.3.4.5 | P0 | | `test_mbtrain_sanity`, `mbtrain_scoreboard` (`check_lane_ctrl`: txDataTriState=0, rxDataEn=0, rxValidEn=0, rxClkEn=1, rxTrackEn=1; no driven-low proof) |
| [ ] | RCC-03 | Partner must not adjust circuit or PI phase params within this state | 4.5.3.4.5 | P1 | | — |
| [ ] | RCC-04 | I/Q correction: partner must apply TCKN_L shift if within HW range, respond Success/Out of Range | 4.5.3.4.5 | P1 | Only for >32 GT/s | — |
| [~] | RCC-05 | On {MBTRAIN.RXCLKCAL done resp}, must exit to MBTRAIN.VALTRAINCENTER | 4.5.3.4.5 | P0 | | `test_mbtrain_sanity`, `mbtrain_scoreboard` (`saw_vtc_start_req`) |

### 13. MBTRAIN.VALTRAINCENTER — Valid-to-Clock Centering

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [ ] | VTC-01 | Must perform Tx-initiated eye width sweep and/or point test on Valid lane | 4.5.3.4.6 | P0 | LinkOpSequenceIO | — |
| [ ] | VTC-02 | Must use 128 iterations continuous VALTRAIN (unscrambled) | 4.5.3.4.6 | P0 | | — |
| [ ] | VTC-03 | Detection success if VALTRAIN errors < threshold | 4.5.3.4.6 | P0 | | — |
| [~] | VTC-04 | On done, must exit to MBTRAIN.VALTRAINVREF | 4.5.3.4.6 | P0 | | `test_mbtrain_sanity`, `mbtrain_scoreboard` (`saw_vtv_start_req`) |

### 14. MBTRAIN.VALTRAINVREF — Valid Vref at Operating Speed

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [ ] | VTV-01 | Optional Vref re-optimization at operating data rate | 4.5.3.4.7 | P1 | Implementation-specific | — |
| [ ] | VTV-02 | If performed, must use 128 iterations continuous VALTRAIN (unscrambled) | 4.5.3.4.7 | P1 | | — |
| [~] | VTV-03 | On {MBTRAIN.VALTRAINVREF end resp}, must exit to MBTRAIN.DATATRAINCENTER1 | 4.5.3.4.7 | P0 | | `test_mbtrain_sanity`, `mbtrain_scoreboard` (`saw_dc1_start_req`) |

### 15. MBTRAIN.DATATRAINCENTER1 — Data-to-Clock Centering

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [ ] | DC1-01 | Must use 4K UI continuous LFSR pattern with correct valid framing | 4.5.3.4.8 | P0 | | — |
| [ ] | DC1-02 | Must perform Tx-initiated eye width sweep and/or point test | 4.5.3.4.8 | P0 | | — |
| [ ] | DC1-03 | Detection success if total error < threshold per lane | 4.5.3.4.8 | P0 | | — |
| [ ] | DC1-04 | On success, must set clock phase to optimal sample point | 4.5.3.4.8 | P0 | | — |
| [~] | DC1-05 | On done, must exit to MBTRAIN.DATATRAINVREF | 4.5.3.4.8 | P0 | | `test_mbtrain_sanity`, `mbtrain_scoreboard` (`saw_dtv_start_req`) |

### 16. MBTRAIN.DATATRAINVREF — Data Vref at Operating Speed

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [ ] | DTV-01 | Must use 4K UI continuous LFSR pattern with valid framing | 4.5.3.4.9 | P0 | | — |
| [~] | DTV-02 | On done, must exit to MBTRAIN.RXDESKEW | 4.5.3.4.9 | P0 | | `test_mbtrain_sanity`, `mbtrain_scoreboard` (`saw_rds_start_req`) |

### 17. MBTRAIN.RXDESKEW — Rx Per-Lane Deskew

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [ ] | RDS-01 | Must use 4K UI continuous LFSR pattern with valid framing | 4.5.3.4.10 | P0 | | — |
| [~] | RDS-02 | On done, must exit to MBTRAIN.DATATRAINCENTER2 | 4.5.3.4.10 | P0 | | `test_mbtrain_sanity`, `mbtrain_scoreboard` (`saw_dc2_start_req`) |

### 18. MBTRAIN.DATATRAINCENTER2 — Final Data Centering

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [ ] | DC2-01 | Must use 4K UI continuous LFSR pattern with valid framing | 4.5.3.4.11 | P0 | | — |
| [~] | DC2-02 | On done, must exit to MBTRAIN.LINKSPEED | 4.5.3.4.11 | P0 | | `test_mbtrain_sanity`, `mbtrain_scoreboard` (`saw_ls_start_req`) |

### 19. MBTRAIN.LINKSPEED — Link Speed Verification

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [ ] | LS-01 | Must verify link at operating speed via Tx-initiated point test or eye sweep | 4.5.3.4.12 | P0 | | — |
| [ ] | LS-02 | If change in Runtime Link Test Control register detected, must exit to PHYRETRAIN | 4.5.3.4.12 | P1 | changeInRuntimeLinkCtrlRegs | — |
| [~] | LS-03 | If link test passes, must exit to LINKINIT | 4.5.3.4.12 | P0 | | `test_mbtrain_sanity`, `mbtrain_scoreboard` (`saw_ls_done_req`, `saw_fsm_done`) |
| [ ] | LS-04 | If link test fails, must exit to PHYRETRAIN with speed degrade encoding | 4.5.3.4.12 | P0 | | — |

### 20. MBTRAIN.REPAIR — Runtime Repair

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [ ] | REP-01 | Must perform lane repair using same flow as MBINIT.REPAIRMB | 4.5.3.4.13 | P1 | Entered from PHYRETRAIN | — |
| [ ] | REP-02 | On done, must exit to MBTRAIN.DATATRAINCENTER2 or SPEEDIDLE if unrepairable | 4.5.3.4.13 | P1 | | — |

### 21. LINKINIT — RDI Bringup

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [ ] | LI-01 | Scrambler LFSR must be RESET upon entering this state | 4.5.3.5 | P0 | | — |
| [ ] | LI-02 | Track/Data/Valid Tx held low; Clock per operating mode | 4.5.3.5 | P0 | | — |
| [~] | LI-03 | Must coordinate with D2D Adapter to complete RDI Active entry | 4.5.3.5 | P0 | RDI / adapter integration | `RdiHandshakeIntegrationTest` (narrow: clock ack staging, wake ack) |
| [ ] | LI-04 | PHY must clear its copy of Start UCIe Link training bit after RDI Active | 4.5.3.5 | P1 | | — |

### 22. ACTIVE — Normal Operation

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [ ] | ACT-01 | All data must be scrambled using LFSR described in 4.4.1 | 4.5.3.6 | P0 | | — |
| [ ] | ACT-02 | Clock gating rules per 5.11 must apply | 4.5.3.6 | P1 | | — |
| [ ] | ACT-03 | PHY must initiate retrain on detecting valid framing error | 4.5.3.7.2 | P0 | pl_error assertion | — |

### 23. PHYRETRAIN — Link Retrain

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [ ] | PR-01 | Adapter-initiated: must complete RDI stall handshake, send {LinkMgmt.RDI.Req.Retrain} | 4.5.3.7.1 | P0 | RDI stall logic | — |
| [ ] | PR-02 | Partner on receiving retrain req must complete stall, transition RDI to Retrain, respond | 4.5.3.7.1 | P0 | | — |
| [ ] | PR-03 | PHY-initiated: must assert pl_error, complete stall, send retrain req | 4.5.3.7.2 | P0 | Valid framing error trigger | — |
| [ ] | PR-04 | Remote-requested: must transition RDI to retrain after stall, respond | 4.5.3.7.3 | P0 | | — |
| [ ] | PR-05 | PHY_IN_RETRAIN variable must be set on entry | 4.5.3.7 | P0 | phyInRetrain flag | — |
| [ ] | PR-06 | Must send {PHYRETRAIN.retrain start req} with retrain encoding from Runtime Link Test register | 4.5.3.7 | P0 | | — |
| [~] | PR-07 | Must resolve retrain encoding per Tables 4-10, 4-11, 4-12 when encodings differ | 4.5.3.7 | P0 | PhyRetrainSidebandHandshake | `PhyRetrainSidebandHandshakeTest` (sub-block loopback, not full LTSM) |
| [ ] | PR-08 | Must exit to resolved training state (TXSELFCAL, SPEEDIDLE, or REPAIR) | 4.5.3.7 | P0 | MBTrainGoToState enum | — |
| [ ] | PR-09 | From LINKSPEED: must follow same encoding resolution flow | 4.5.3.7.4 | P1 | | — |
| [ ] | PR-10 | For multi-module: retrain encoding must be same for all modules | 4.5.3.7 | P2 | Multi-module not implemented | — |

### 24. TRAINERROR — Error Handling

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [ ] | TE-01 | Data/Valid/Clock/Track Tx must be tri-stated; Rx permitted to be disabled | 4.5.3.8 | P0 | | — |
| [~] | TE-02 | If sideband active, must perform TRAINERROR handshake before entering | 4.5.3.8 | P0 | Observed on fused `io_sbLaneIo` in **`make ltsm`** (`test_ltsm_mbinit_repairval_trainerror`) | `test_ltsm_mbinit_repairval_trainerror` |
| [~] | TE-03 | Must send {TRAINERROR Entry req} and wait for {TRAINERROR Entry resp} | 4.5.3.8 | P0 | REQ (`msgCode==0xE5`) on DUT SB TX, RESP (`0xEA`) on SB RX in same test | `test_ltsm_mbinit_repairval_trainerror` |
| [~] | TE-04 | If no response for 8ms, LTSM transitions to TRAINERROR unconditionally | 4.5.3.8 | P0 | Timeout fallback | `test_sbinit_timeout` covers SBINIT timeout-to-error path only |
| [ ] | TE-05 | In-progress sideband packets must finish before entering RESET | 4.5.3.8 | P1 | | — |
| [ ] | TE-06 | If RDI in LinkError, PHY must remain in TRAINERROR as long as RDI is in LinkError | 4.5.3.8 | P0 | | — |
| [ ] | TE-07 | Exit from TRAINERROR to RESET is implementation-specific | 4.5.3.8 | P1 | | — |

### 25. L1/L2 — Power Management

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [ ] | PM-01 | Data/Valid/Clock/Track Tx tri-stated; Rx permitted to be disabled | 4.5.3.9 | P0 | | — |
| [ ] | PM-02 | On L1 exit request, must exit to MBTRAIN.SPEEDIDLE | 4.5.3.9 | P0 | goToState = goToSPEEDIDLE | — |
| [ ] | PM-03 | On L2 exit request, must exit to RESET | 4.5.3.9 | P0 | | — |
| [ ] | PM-04 | L2SPD (Sideband Power Down) negotiation via SBFE if supported | 4.5.3.9.1 | P2 | Optional feature | — |

### 26. RESET — Initial State

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [ ] | RST-01 | PHY must remain in RESET for minimum 4ms upon every entry | 4.5.3.1 | P0 | resetMinWait logic | — |
| [ ] | RST-02 | PLLs must be allowed to lock within this time | 4.5.3.1 | P0 | pllLock input | — |
| [ ] | RST-03 | Must not exit RESET until pwrGood, pllLock, and resetMinWait all asserted | 4.5.3.1 | P0 | Exit conditions in LTSM | — |
| [ ] | RST-04 | Exit to SBINIT when training is triggered | 4.5.3.1 | P0 | triggerTraining | — |

### 27. Cross-Cutting: Sideband Handshake Protocol

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [~] | XC-01 | Every sub-state uses req/resp sideband handshake pattern for entry/exit coordination | 4.5.3 | P0 | SidebandMessageExchanger | Exercised for SBINIT + MBINIT + would-be MBTRAIN seq |
| [~] | XC-02 | Sideband messages must use correct opcode, msgcode, msgsubcode encodings per Ch 7/8 | 7, 8 | P0 | SBMsgCreate / SBMsgCompare | MBINIT/SBINIT scoreboards check selected messages |
| [ ] | XC-03 | Requester and responder currentState must be synchronized at all transitions | N/A | P0 | TODO SVA in MBInitSM/MBTrainSM | — |
| [ ] | XC-04 | 8ms global timeout for training states; reset on substate transitions | 4.5.3 | P0 | timeoutCounter logic | Only SBINIT timeout exercised (`test_sbinit_timeout`) |

### 28. Cross-Cutting: Mainband Lane Control

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [~] | XC-05 | Tx tri-state and Rx enable must be correct per-state as specified in each sub-state | 4.5.3 | P0 | mbLaneCtrlIo per state | `test_mbtrain_sanity` (12 MBTRAIN states), `test_mbinit_sanity` (7 MBINIT states); both scoreboards have `check_lane_ctrl()`; txValidTriState in REPAIRVAL skipped (substate-dependent) |
| [ ] | XC-06 | Clock Tx mode must match operating speed and clock mode (strobe vs continuous) | 4.5.3 | P1 | | — |
| [ ] | XC-07 | Valid framing must be correct when accompanying LFSR data patterns | 4.1.2 | P0 | | — |

### 29. Cross-Cutting: Pattern Generation and Comparison

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [ ] | XC-08 | LFSR must follow polynomial and implementation per 4.4.1 | 4.4.1 | P0 | UcieLFSR module | `ParallelGaloisLFSRTest.scala` commented out |
| [ ] | XC-09 | VALTRAIN pattern: four 1s and four 0s, must NOT be scrambled | 4.4, Table 4-5 | P0 | | — |
| [ ] | XC-10 | Per Lane ID pattern: must NOT be scrambled | 4.4, Table 4-8 | P0 | | — |
| [ ] | XC-11 | LFSR pattern must be accompanied by correct valid framing | 4.1.2, 4.4.1 | P0 | | — |
| [ ] | XC-12 | LFSR must be RESET on entry to LINKINIT | 4.5.3.5 | P0 | | — |

### 30. Cross-Cutting: RDI State Machine

| Done | ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping | Evidence |
|------|-----|-------------|----------|-----|---------------------|----------|
| [~] | XC-13 | RDI RESET -> ACTIVE transition via sideband {LinkMgmt.RDI.Req/Rsp.Active} | 10.1.6 | P0 | Full SM wider than tests | Not isolated; adapter integration partial coverage |
| [ ] | XC-14 | RDI ACTIVE -> Retrain: stall handshake (pl_stallreq/lp_stallack) required | 10.3.3.4 | P0 | RDIStallRequester | — |
| [~] | XC-15 | RDI Retrain -> ACTIVE: wake handshake required | 10.2.8 | P0 | RDIWakeHandshakeResponder | `RdiHandshakeIntegrationTest` wake section |
| [ ] | XC-16 | RDI ACTIVE -> L1/L2: PM entry flow | 10.3.3 | P1 | Not yet implemented in RDI SM | — |
| [ ] | XC-17 | RDI -> LinkError escalation from TRAINERROR | 10.3.3 | P1 | Not yet implemented in RDI SM | — |

## 5. Recommended test strategy

### Phase 1: Sub-FSM end-to-end (in progress)

SBINIT and MBINIT sideband paths: **expand** to mainband monitors (VALTRAIN, LFSR UI counts, `mbLaneCtrlIo`). Add PARAM stall / SBFE (MP-07/08).

### Phase 2: MBTRAIN + top-level LTSM

1. Add `mbtrain_test` that runs `seq_mbtrain_full` and extend `mbtrain_scoreboard` beyond SB opcodes (see TODO for per-state lane control).
2. Run full `LinkTrainingSM` / `LogicalPhy` / `UcieTop` RESET → ACTIVE in sim; close §21–26 and §27–30 P0 rows.

### Phase 3: Error and corner cases

Timeouts everywhere, TRAINERROR handshakes, unrepairable lanes, retrain table sweep, negative RDI.

### Phase 4: RDI completion

Stall/retrain/PM/LinkError — align with XC-14–17.

## 6. Suggested SVA checklist

| Done | Assertion theme | Notes |
|------|-----------------|-------|
| [ ] | State sync (requester/responder) | TODO in MBInitSM/MBTrainSM |
| [ ] | Timeout monotonicity | |
| [ ] | RESET minimum residency (4 ms) | |
| [ ] | Tx tri-state in TRAINERROR | |
| [ ] | LFSR reset on LINKINIT entry | |
| [ ] | SB mode RAW → PACKET | |
| [ ] | Training patterns unscrambled | |
| [ ] | Valid framing with LFSR | |

Recommend binding these at `LogicalPhy` / top when integrated.

---

*Last checklist audit: repository paths `uvm/` and `scala/test/` on `dev-verification` lineage; update Status/Evidence when adding tests.*
