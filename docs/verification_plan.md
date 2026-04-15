# UCIe LogPHY Verification Plan
**UCIe Spec Rev 3.0**

## 1. Overview

This document defines the verification plan for the UCIe LogPHY layer implementation at https://github.com/ucb-bar/ucie (dev branch). It identifies all mandatory requirements from the UCIe Specification Rev 3.0 that must be verified through simulation, organized by LTSM state and cross-cutting concerns.

## 2. RTL Implementation Status

| Module | Status |
|---|---|
| SBInitSM (requester/responder) | Functional, loopback test exists (commented out) |
| MBInitSM (~1300 lines) | All 6 sub-states implemented with requester/responder split |
| MBTrainSM (~2200 lines) | All 12+ sub-states implemented, Vref sweep DontCare placeholders remain |
| RDIStateMachine | Only RESET to ACTIVE transition implemented |
| PhyRetrainSidebandHandshake and TrainError | Modules exist |
| LinkTrainingSM (top-level) | Entirely commented out; sub-FSM wiring is incomplete |
| Existing tests (SBInitSMTest, LinkTrainingSMTest) | All commented out |

## 3. Priority Definitions

- **P0 (Must Have):** Blocks basic link bringup functionality. Required for RESET-to-ACTIVE path.
- **P1 (Should Have):** Required for spec compliance and robustness, including error paths and edge cases.
- **P2 (Nice to Have):** Optional features, multi-module support, or items out of current implementation scope.

**Notes:**
- We aren't implementing any debugging features (in spec)
- For Constrained-Random, messages can't be random. We want to put the right bits for having the DUT respond to it.

## 4. Verification Requirements

### 1. SBINIT — Sideband Initialization

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| SB-01 | UCIe Module must send 64-UI clock pattern (1010...) and 32-UI low on both SB data Tx | 4.5.3.2 | P0 | Pattern gen in SBInitRequester |
| SB-02 | UCIe Module Partner must sample incoming SB data patterns with incoming clock | 4.5.3.2 | P0 | |
| SB-03 | On pattern detection on at least one SB data-clock Rx combo, must stop sending after completing current iteration | 4.5.3.2 | P0 | detectPatternCounter logic |
| SB-04 | If pattern not detected, must continue alternating for total of 8ms then timeout to TRAINERROR | 4.5.3.2 | P0 | Timeout path critical |
| SB-05 | After detection, SB Tx/Rx must be enabled for functional sideband messages | 4.5.3.2 | P0 | RAW to PACKET mode transition |
| SB-06 | Must send {SBINIT Out of Reset} sideband message continuously until partner detection | 4.5.3.2 | P0 | |
| SB-07 | Must send {SBINIT done req} and wait for {SBINIT done resp} before exiting to MBINIT | 4.5.3.2 | P0 | |
| SB-08 | Module partner must ignore received {SBINIT done req} if not ready to proceed | 4.5.3.2 | P1 | |
| SB-09 | Module partner must collapse multiple outstanding {SBINIT done req} messages into single response | 4.5.3.2 | P1 | Edge case |

### 2. MBINIT.PARAM — Parameter Negotiation

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| MP-01 | Must exchange Tx voltage swing, max data rate, clock mode, clock phase, UCIe-Sx8, SB feature extensions, Tx adjust runtime, module ID via sideband | 4.5.3.3.1 | P0 | MBInitRequester/Responder |
| MP-02 | UCIe Module Partner must respond with max common data rate (min of local and remote) | 4.5.3.3.1 | P0 | localNegotiatedMaxDataRate logic |
| MP-03 | Clock mode in response must match the request value | 4.5.3.3.1 | P0 | interoperableParamsComparison |
| MP-04 | If interoperable params not found, must escalate error | 4.5.3.3.1 | P0 | interoperableParamsErrorFlag |
| MP-05 | All modules in multi-module design must have same parameter values (except Module ID) | 4.5.3.3.1 | P2 | Multi-module not implemented |
| MP-06 | On receiving {MBINIT.PARAM configuration resp}, must exit to MBINIT.CAL | 4.5.3.3.1 | P0 | |
| MP-07 | MBINIT stall handling: {MBINIT.PARAM SBFE resp} with stall encoding must be sent once every 4ms | 4.5.3.3.1.2 | P1 | Stall conditions |
| MP-08 | Sideband Feature Extensions (SBFE) negotiation if SB_MGMT_UP flag is set | 4.5.3.3.1.1 | P1 | |

### 3. MBINIT.CAL — Calibration

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| MC-01 | Must send {MBINIT.CAL Done req} and wait for {MBINIT.CAL Done resp} | 4.5.3.3.2 | P0 | mbInitCalDone input |
| MC-02 | On receiving {MBINIT.CAL Done resp}, must exit to MBINIT.REPAIRCLK | 4.5.3.3.2 | P0 | |

### 4. MBINIT.REPAIRCLK — Clock/Track Repair

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| RC-01 | Must enable Tx/Rx on Clock, Track, and redundant lanes | 4.5.3.3.3 | P0 | |
| RC-02 | Must send clock repair pattern and check repair success via Tx-initiated point test | 4.5.3.3.3 | P0 | Pattern must not be scrambled |
| RC-03 | If clock/track unrepairable, must exit to TRAINERROR via handshake | 4.5.3.3.3 | P0 | Error path |
| RC-04 | If repair applied successfully, must verify by repeating point test | 4.5.3.3.3 | P1 | |
| RC-05 | On {MBINIT.REPAIRCLK done resp}, must exit to MBINIT.REPAIRVAL | 4.5.3.3.3 | P0 | |

### 5. MBINIT.REPAIRVAL — Valid Lane Repair

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| RV-01 | Must set clock phase at center of data UI; partner must sample Valid with forwarded clock | 4.5.3.3.4 | P0 | |
| RV-02 | All Data lanes must be held low during Valid repair | 4.5.3.3.4 | P0 | mbLaneCtrlIo check |
| RV-03 | Must send 128 iterations of VALTRAIN pattern (unscrambled) on VLD | 4.5.3.3.4 | P0 | PatternWriter config |
| RV-04 | Must repeat for RVLD (redundant valid) | 4.5.3.3.4 | P0 | |
| RV-05 | If repair needed, must apply repair and verify success | 4.5.3.3.4 | P1 | |
| RV-06 | If repair unsuccessful or unrepairable, must exit to TRAINERROR | 4.5.3.3.4 | P0 | |
| RV-07 | On {MBINIT.REPAIRVAL done resp}, must exit to MBINIT.REVERSALMB | 4.5.3.3.4 | P0 | |

### 6. MBINIT.REVERSALMB — Lane Reversal Detection

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| LR-01 | Must send {MBINIT.REVERSALMB init req} and wait for resp | 4.5.3.3.5 | P0 | |
| LR-02 | Must send Per Lane ID pattern on all N data lanes (128 iterations, unscrambled) | 4.5.3.3.5 | P0 | |
| LR-03 | Partner must perform per-lane compare on all N Rx lanes | 4.5.3.3.5 | P0 | PatternReader compare |
| LR-04 | Must correctly detect lane reversal and apply if needed | 4.5.3.3.5 | P0 | applyLaneReversal output |
| LR-05 | If x32 partner connected to x64, must recognize width difference from param exchange | 4.5.3.3.5 | P1 | interpretBy8Lane |
| LR-06 | On {MBINIT.REVERSALMB done resp}, must exit to MBINIT.REPAIRMB | 4.5.3.3.5 | P0 | |
| LR-07 | Must exit to TRAINERROR on detection failure | 4.5.3.3.5 | P0 | |

### 7. MBINIT.REPAIRMB — Data Lane Repair

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| RM-01 | Must send 128 iterations of Per Lane ID pattern (unscrambled) for lane testing | 4.5.3.3.6 | P0 | |
| RM-02 | Rx must check pass/fail on data lanes and redundant lanes | 4.5.3.3.6 | P0 | |
| RM-03 | Must apply single-lane or two-lane repair per repair resources | 4.5.3.3.6 | P1 | Repair mux chain logic |
| RM-04 | Must send {MBINIT.REPAIRMB apply degrade req} with correct lane map code if width degrade needed | 4.5.3.3.6 | P1 | Width degrade negotiation |
| RM-05 | If post-repair errors persist, must exit to TRAINERROR | 4.5.3.3.6 | P0 | |
| RM-06 | If width changed on Tx or Rx, must repeat lane test (Step 2) | 4.5.3.3.6 | P1 | txWidthChanged/rxWidthChanged |
| RM-07 | If unrepairable, must exit to TRAINERROR | 4.5.3.3.6 | P0 | |
| RM-08 | On {MBINIT.REPAIRMB end resp}, must exit to MBTRAIN | 4.5.3.3.6 | P0 | |

### 8. MBTRAIN.VALVREF — Valid Vref Training

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| VV-01 | Partner must set forwarded clock phase at center of data UI on Tx | 4.5.3.4.1 | P0 | |
| VV-02 | Must sample Valid with forwarded clock; all data lanes and Track held low | 4.5.3.4.1 | P0 | mbLaneCtrlIo |
| VV-03 | Must use 128 iterations of continuous VALTRAIN pattern (unscrambled) | 4.5.3.4.1 | P0 | |
| VV-04 | Detection success if VALTRAIN errors < per-lane threshold | 4.5.3.4.1 | P0 | maxErrorThresholdPerLane |
| VV-05 | LFSR RESET has no impact in this state | 4.5.3.4.1 | P1 | |
| VV-06 | On {MBTRAIN.VALVREF end resp}, must exit to MBTRAIN.DATAVREF | 4.5.3.4.1 | P0 | |

### 9. MBTRAIN.DATAVREF — Data Vref Training

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| DV-01 | Must use 4K UI of continuous LFSR pattern with correct valid framing | 4.5.3.4.2 | P0 | |
| DV-02 | Detection success if total error count < threshold per lane | 4.5.3.4.2 | P0 | |
| DV-03 | On {MBTRAIN.DATAVREF end resp}, must exit to MBTRAIN.SPEEDIDLE | 4.5.3.4.2 | P0 | |

### 10. MBTRAIN.SPEEDIDLE — Speed Transition Idle

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| SI-01 | If from DATAVREF: must transition to highest common speed | 4.5.3.4.3 | P0 | freqSel output |
| SI-02 | If from L1: must restore operating speed from last ACTIVE | 4.5.3.4.3 | P0 | goToState logic |
| SI-03 | If from LINKSPEED/PHYRETRAIN (speed degrade) and not 4GT/s: must pick next-lower rate | 4.5.3.4.3 | P0 | Speed degrade path |
| SI-04 | Else must exit to TRAINERROR | 4.5.3.4.3 | P0 | |
| SI-05 | Link width set to width from last REPAIRMB or REPAIR exit | 4.5.3.4.3 | P1 | |
| SI-06 | On {MBTRAIN.SPEEDIDLE done resp}, must exit to MBTRAIN.TXSELFCAL | 4.5.3.4.3 | P0 | |

### 11. MBTRAIN.TXSELFCAL — Tx Self-Calibration

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| TC-01 | Data/Clock/Valid/Track Tx are tri-stated; Rx permitted to be disabled | 4.5.3.4.4 | P0 | |
| TC-02 | On {MBTRAIN.TXSELFCAL Done resp}, must exit to MBTRAIN.RXCLKCAL | 4.5.3.4.4 | P0 | |

### 12. MBTRAIN.RXCLKCAL — Rx Clock Calibration

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| RCC-01 | Partner must start sending forwarded clock and Track after start req received | 4.5.3.4.5 | P0 | rxClkCalSendFwClkPattern |
| RCC-02 | Tx clock must be free running; all data lanes and Valid held low | 4.5.3.4.5 | P0 | |
| RCC-03 | Partner must not adjust circuit or PI phase params within this state | 4.5.3.4.5 | P1 | |
| RCC-04 | I/Q correction: partner must apply TCKN_L shift if within HW range, respond Success/Out of Range | 4.5.3.4.5 | P1 | Only for >32 GT/s |
| RCC-05 | On {MBTRAIN.RXCLKCAL done resp}, must exit to MBTRAIN.VALTRAINCENTER | 4.5.3.4.5 | P0 | |

### 13. MBTRAIN.VALTRAINCENTER — Valid-to-Clock Centering

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| VTC-01 | Must perform Tx-initiated eye width sweep and/or point test on Valid lane | 4.5.3.4.6 | P0 | LinkOpSequenceIO |
| VTC-02 | Must use 128 iterations continuous VALTRAIN (unscrambled) | 4.5.3.4.6 | P0 | |
| VTC-03 | Detection success if VALTRAIN errors < threshold | 4.5.3.4.6 | P0 | |
| VTC-04 | On done, must exit to MBTRAIN.VALTRAINVREF | 4.5.3.4.6 | P0 | |

### 14. MBTRAIN.VALTRAINVREF — Valid Vref at Operating Speed

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| VTV-01 | Optional Vref re-optimization at operating data rate | 4.5.3.4.7 | P1 | Implementation-specific |
| VTV-02 | If performed, must use 128 iterations continuous VALTRAIN (unscrambled) | 4.5.3.4.7 | P1 | |
| VTV-03 | On {MBTRAIN.VALTRAINVREF end resp}, must exit to MBTRAIN.DATATRAINCENTER1 | 4.5.3.4.7 | P0 | |

### 15. MBTRAIN.DATATRAINCENTER1 — Data-to-Clock Centering

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| DC1-01 | Must use 4K UI continuous LFSR pattern with correct valid framing | 4.5.3.4.8 | P0 | |
| DC1-02 | Must perform Tx-initiated eye width sweep and/or point test | 4.5.3.4.8 | P0 | |
| DC1-03 | Detection success if total error < threshold per lane | 4.5.3.4.8 | P0 | |
| DC1-04 | On success, must set clock phase to optimal sample point | 4.5.3.4.8 | P0 | |
| DC1-05 | On done, must exit to MBTRAIN.DATATRAINVREF | 4.5.3.4.8 | P0 | |

### 16. MBTRAIN.DATATRAINVREF — Data Vref at Operating Speed

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| DTV-01 | Must use 4K UI continuous LFSR pattern with valid framing | 4.5.3.4.9 | P0 | |
| DTV-02 | On done, must exit to MBTRAIN.RXDESKEW | 4.5.3.4.9 | P0 | |

### 17. MBTRAIN.RXDESKEW — Rx Per-Lane Deskew

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| RDS-01 | Must use 4K UI continuous LFSR pattern with valid framing | 4.5.3.4.10 | P0 | |
| RDS-02 | On done, must exit to MBTRAIN.DATATRAINCENTER2 | 4.5.3.4.10 | P0 | |

### 18. MBTRAIN.DATATRAINCENTER2 — Final Data Centering

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| DC2-01 | Must use 4K UI continuous LFSR pattern with valid framing | 4.5.3.4.11 | P0 | |
| DC2-02 | On done, must exit to MBTRAIN.LINKSPEED | 4.5.3.4.11 | P0 | |

### 19. MBTRAIN.LINKSPEED — Link Speed Verification

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| LS-01 | Must verify link at operating speed via Tx-initiated point test or eye sweep | 4.5.3.4.12 | P0 | |
| LS-02 | If change in Runtime Link Test Control register detected, must exit to PHYRETRAIN | 4.5.3.4.12 | P1 | changeInRuntimeLinkCtrlRegs |
| LS-03 | If link test passes, must exit to LINKINIT | 4.5.3.4.12 | P0 | |
| LS-04 | If link test fails, must exit to PHYRETRAIN with speed degrade encoding | 4.5.3.4.12 | P0 | |

### 20. MBTRAIN.REPAIR — Runtime Repair

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| REP-01 | Must perform lane repair using same flow as MBINIT.REPAIRMB | 4.5.3.4.13 | P1 | Entered from PHYRETRAIN |
| REP-02 | On done, must exit to MBTRAIN.DATATRAINCENTER2 or SPEEDIDLE if unrepairable | 4.5.3.4.13 | P1 | |

### 21. LINKINIT — RDI Bringup

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| LI-01 | Scrambler LFSR must be RESET upon entering this state | 4.5.3.5 | P0 | |
| LI-02 | Track/Data/Valid Tx held low; Clock per operating mode | 4.5.3.5 | P0 | |
| LI-03 | Must coordinate with D2D Adapter to complete RDI Active entry | 4.5.3.5 | P0 | RDI SM currently only RESET->ACTIVE |
| LI-04 | PHY must clear its copy of Start UCIe Link training bit after RDI Active | 4.5.3.5 | P1 | |

### 22. ACTIVE — Normal Operation

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| ACT-01 | All data must be scrambled using LFSR described in 4.4.1 | 4.5.3.6 | P0 | |
| ACT-02 | Clock gating rules per 5.11 must apply | 4.5.3.6 | P1 | |
| ACT-03 | PHY must initiate retrain on detecting valid framing error | 4.5.3.7.2 | P0 | pl_error assertion |

### 23. PHYRETRAIN — Link Retrain

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| PR-01 | Adapter-initiated: must complete RDI stall handshake, send {LinkMgmt.RDI.Req.Retrain} | 4.5.3.7.1 | P0 | RDI stall logic |
| PR-02 | Partner on receiving retrain req must complete stall, transition RDI to Retrain, respond | 4.5.3.7.1 | P0 | |
| PR-03 | PHY-initiated: must assert pl_error, complete stall, send retrain req | 4.5.3.7.2 | P0 | Valid framing error trigger |
| PR-04 | Remote-requested: must transition RDI to retrain after stall, respond | 4.5.3.7.3 | P0 | |
| PR-05 | PHY_IN_RETRAIN variable must be set on entry | 4.5.3.7 | P0 | phyInRetrain flag |
| PR-06 | Must send {PHYRETRAIN.retrain start req} with retrain encoding from Runtime Link Test register | 4.5.3.7 | P0 | |
| PR-07 | Must resolve retrain encoding per Tables 4-10, 4-11, 4-12 when encodings differ | 4.5.3.7 | P0 | PhyRetrainSidebandHandshake |
| PR-08 | Must exit to resolved training state (TXSELFCAL, SPEEDIDLE, or REPAIR) | 4.5.3.7 | P0 | MBTrainGoToState enum |
| PR-09 | From LINKSPEED: must follow same encoding resolution flow | 4.5.3.7.4 | P1 | |
| PR-10 | For multi-module: retrain encoding must be same for all modules | 4.5.3.7 | P2 | Multi-module not implemented |

### 24. TRAINERROR — Error Handling

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| TE-01 | Data/Valid/Clock/Track Tx must be tri-stated; Rx permitted to be disabled | 4.5.3.8 | P0 | |
| TE-02 | If sideband active, must perform TRAINERROR handshake before entering | 4.5.3.8 | P0 | TrainErrorRequester/Responder |
| TE-03 | Must send {TRAINERROR Entry req} and wait for {TRAINERROR Entry resp} | 4.5.3.8 | P0 | |
| TE-04 | If no response for 8ms, LTSM transitions to TRAINERROR unconditionally | 4.5.3.8 | P0 | Timeout fallback |
| TE-05 | In-progress sideband packets must finish before entering RESET | 4.5.3.8 | P1 | |
| TE-06 | If RDI in LinkError, PHY must remain in TRAINERROR as long as RDI is in LinkError | 4.5.3.8 | P0 | |
| TE-07 | Exit from TRAINERROR to RESET is implementation-specific | 4.5.3.8 | P1 | |

### 25. L1/L2 — Power Management

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| PM-01 | Data/Valid/Clock/Track Tx tri-stated; Rx permitted to be disabled | 4.5.3.9 | P0 | |
| PM-02 | On L1 exit request, must exit to MBTRAIN.SPEEDIDLE | 4.5.3.9 | P0 | goToState = goToSPEEDIDLE |
| PM-03 | On L2 exit request, must exit to RESET | 4.5.3.9 | P0 | |
| PM-04 | L2SPD (Sideband Power Down) negotiation via SBFE if supported | 4.5.3.9.1 | P2 | Optional feature |

### 26. RESET — Initial State

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| RST-01 | PHY must remain in RESET for minimum 4ms upon every entry | 4.5.3.1 | P0 | resetMinWait logic |
| RST-02 | PLLs must be allowed to lock within this time | 4.5.3.1 | P0 | pllLock input |
| RST-03 | Must not exit RESET until pwrGood, pllLock, and resetMinWait all asserted | 4.5.3.1 | P0 | Exit conditions in LTSM |
| RST-04 | Exit to SBINIT when training is triggered | 4.5.3.1 | P0 | triggerTraining |

### 27. Cross-Cutting: Sideband Handshake Protocol

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| XC-01 | Every sub-state uses req/resp sideband handshake pattern for entry/exit coordination | 4.5.3 | P0 | SidebandMessageExchanger |
| XC-02 | Sideband messages must use correct opcode, msgcode, msgsubcode encodings per Ch 7/8 | 7, 8 | P0 | SBMsgCreate / SBMsgCompare |
| XC-03 | Requester and responder currentState must be synchronized at all transitions | N/A | P0 | TODO SVA in MBInitSM/MBTrainSM |
| XC-04 | 8ms global timeout for training states; reset on substate transitions | 4.5.3 | P0 | timeoutCounter logic |

### 28. Cross-Cutting: Mainband Lane Control

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| XC-05 | Tx tri-state and Rx enable must be correct per-state as specified in each sub-state | 4.5.3 | P0 | mbLaneCtrlIo per state |
| XC-06 | Clock Tx mode must match operating speed and clock mode (strobe vs continuous) | 4.5.3 | P1 | |
| XC-07 | Valid framing must be correct when accompanying LFSR data patterns | 4.1.2 | P0 | |

### 29. Cross-Cutting: Pattern Generation and Comparison

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| XC-08 | LFSR must follow polynomial and implementation per 4.4.1 | 4.4.1 | P0 | UcieLFSR module |
| XC-09 | VALTRAIN pattern: four 1s and four 0s, must NOT be scrambled | 4.4, Table 4-5 | P0 | |
| XC-10 | Per Lane ID pattern: must NOT be scrambled | 4.4, Table 4-8 | P0 | |
| XC-11 | LFSR pattern must be accompanied by correct valid framing | 4.1.2, 4.4.1 | P0 | |
| XC-12 | LFSR must be RESET on entry to LINKINIT | 4.5.3.5 | P0 | |

### 30. Cross-Cutting: RDI State Machine

| ID | Requirement | Spec Ref | Pri | Notes / RTL Mapping |
|---|---|---|---|---|
| XC-13 | RDI RESET -> ACTIVE transition via sideband {LinkMgmt.RDI.Req/Rsp.Active} | 10.1.6 | P0 | Currently only path implemented |
| XC-14 | RDI ACTIVE -> Retrain: stall handshake (pl_stallreq/lp_stallack) required | 10.3.3.4 | P0 | RDIStallRequester |
| XC-15 | RDI Retrain -> ACTIVE: wake handshake required | 10.2.8 | P0 | RDIWakeHandshakeResponder |
| XC-16 | RDI ACTIVE -> L1/L2: PM entry flow | 10.3.3 | P1 | Not yet implemented in RDI SM |
| XC-17 | RDI -> LinkError escalation from TRAINERROR | 10.3.3 | P1 | Not yet implemented in RDI SM |

## 5. Recommended Test Strategy

### Phase 1: Sub-FSM End-to-End (Immediate)

Focus on MBInitSM and MBTrainSM since these contain the bulk of the logic and are testable today. Use loopback test harnesses (similar to the commented-out SBInitSMTestHarnessLoopback) that wire requester Tx to responder Rx. Drive localPhySettings inputs and verify negotiated outputs, state transitions, and sideband message sequences. Target all P0 items in sections 2-20.

### Phase 2: Top-Level LTSM Integration (After LinkTrainingSM is wired up)

Once LinkTrainingSM is completed, run full RESET to ACTIVE sequences. Verify timeout behavior at each state, TRAINERROR entry/exit from every state, and correct top-level state transitions. Target P0 items in sections 21-26 and all cross-cutting items (sections 27-30).

### Phase 3: Error and Corner Cases

Inject errors: sideband message corruption/drops, pattern detection failures, timeout expiry at each state, unrepairable lane scenarios, mismatched parameter negotiation, retrain encoding resolution across all 9 combinations in Table 4-12. Target all P1 items.

### Phase 4: RDI State Machine Completion

Extend RDI SM beyond RESET to ACTIVE to support Retrain, L1/L2, and LinkError transitions. Verify stall/wake handshakes and PM entry/exit flows. Target P1 items in section 30.

## 6. Suggested SVA Checklist

The RTL source contains several TODO comments for SVAs. The following assertions are recommended:

1. **State Synchronization:** Requester and responder currentState must match at every state transition (noted as TODO in both MBInitSM.scala and MBTrainSM.scala).
2. **Timeout Monotonicity:** Timeout counter must increment every cycle when enabled and not reset.
3. **RESET Minimum Residency:** LTSM must remain in RESET for at least 4ms worth of clock cycles before exiting.
4. **Tx Tri-State in TRAINERROR:** All mainband Tx must be tri-stated whenever LTSM is in TRAINERROR.
5. **LFSR Reset on LINKINIT Entry:** Scrambler LFSR must be reset when LTSM transitions to LINKINIT.
6. **Sideband Mode Transition:** SB Rx/Tx mode must be RAW only during RESET and early SBINIT, then transition to PACKET.
7. **No Scrambling of Training Patterns:** VALTRAIN and Per Lane ID patterns must not pass through scrambler.
8. **Valid Framing with LFSR:** Whenever LFSR pattern is transmitted on data lanes, valid framing must be asserted correctly per 4.1.2.
