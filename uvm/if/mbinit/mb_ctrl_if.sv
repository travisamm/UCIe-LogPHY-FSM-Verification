`ifndef MB_CTRL_IF_SV
`define MB_CTRL_IF_SV

// ---------------------------------------------------------------------------
// mb_ctrl_if  (MBINIT FSM control + PHY settings + state/status bus)
// ---------------------------------------------------------------------------
// The non-lane, non-service control surface of MBInitSM:
//   * fsmCtrl   - start (TB drives), done/error/substateTransitioning (DUT)
//   * localPhySettings_*     - TB-driven PARAM negotiation inputs
//   * negotiatedPhySettings_*- DUT-driven negotiated outputs
//   * state/status outputs   - currentState, using*, applyLaneReversal,
//                              functional-lane counts, width-changed flags,
//                              interoperableParamsNotFound
//
// interoperableParamsNotFound is internal in the elaborated RTL and is forwarded
// into the TB by mbinit_bind_exports; in Pass 2 it continues to land in
// mbinit_if and is mirrored here.
//
// Pass 2 staging: passive observation mirror of mbinit_if (DUT stays on vif).
// ---------------------------------------------------------------------------
interface mb_ctrl_if(input logic clock, input logic reset);
  // FSM control
  logic        fsmCtrl_start;                 // TB drives (kick the MBINIT FSM)
  logic        fsmCtrl_substateTransitioning; // DUT drives
  logic        fsmCtrl_error;                 // DUT drives
  logic        fsmCtrl_done;                  // DUT drives

  // Local PHY settings (TB drives)
  logic        localPhySettings_valid;
  logic [4:0]  localPhySettings_voltageSwing;
  logic [3:0]  localPhySettings_maxDataRate;
  logic        localPhySettings_clockMode;
  logic        localPhySettings_clockPhase;
  logic        localPhySettings_ucieSx8;
  logic        localPhySettings_sbFeatExt;
  logic        localPhySettings_txAdjRuntime;
  logic [1:0]  localPhySettings_moduleId;

  // Negotiated PHY settings (DUT drives)
  logic        negotiatedPhySettings_valid;
  logic [4:0]  negotiatedPhySettings_voltageSwing;
  logic [3:0]  negotiatedPhySettings_maxDataRate;
  logic        negotiatedPhySettings_clockMode;
  logic        negotiatedPhySettings_clockPhase;
  logic [1:0]  negotiatedPhySettings_moduleId;

  // State / status outputs (DUT drives)
  logic [2:0]  currentState;
  logic        interoperableParamsNotFound;
  logic        usingPatternWriter;
  logic        usingPatternReader;
  logic        applyLaneReversal;
  logic [2:0]  localFunctionalLanes;
  logic        txWidthChanged;
  logic [2:0]  remoteFunctionalLanes;
  logic        rxWidthChanged;

  // Driver view: TB drives fsmCtrl_start + localPhySettings_*, samples the rest.
  clocking drv_cb @(posedge clock);
    default input #1step output #1;
    output fsmCtrl_start;
    output localPhySettings_valid;
    output localPhySettings_voltageSwing;
    output localPhySettings_maxDataRate;
    output localPhySettings_clockMode;
    output localPhySettings_clockPhase;
    output localPhySettings_ucieSx8;
    output localPhySettings_sbFeatExt;
    output localPhySettings_txAdjRuntime;
    output localPhySettings_moduleId;
    input  fsmCtrl_substateTransitioning;
    input  fsmCtrl_error;
    input  fsmCtrl_done;
    input  negotiatedPhySettings_valid;
    input  negotiatedPhySettings_voltageSwing;
    input  negotiatedPhySettings_maxDataRate;
    input  negotiatedPhySettings_clockMode;
    input  negotiatedPhySettings_clockPhase;
    input  negotiatedPhySettings_moduleId;
    input  currentState;
    input  interoperableParamsNotFound;
    input  usingPatternWriter;
    input  usingPatternReader;
    input  applyLaneReversal;
    input  localFunctionalLanes;
    input  txWidthChanged;
    input  remoteFunctionalLanes;
    input  rxWidthChanged;
  endclocking

  // Monitor view: sample everything.
  clocking mon_cb @(posedge clock);
    default input #1step;
    input fsmCtrl_start;
    input fsmCtrl_substateTransitioning;
    input fsmCtrl_error;
    input fsmCtrl_done;
    input localPhySettings_valid;
    input localPhySettings_voltageSwing;
    input localPhySettings_maxDataRate;
    input localPhySettings_clockMode;
    input localPhySettings_clockPhase;
    input localPhySettings_ucieSx8;
    input localPhySettings_sbFeatExt;
    input localPhySettings_txAdjRuntime;
    input localPhySettings_moduleId;
    input negotiatedPhySettings_valid;
    input negotiatedPhySettings_voltageSwing;
    input negotiatedPhySettings_maxDataRate;
    input negotiatedPhySettings_clockMode;
    input negotiatedPhySettings_clockPhase;
    input negotiatedPhySettings_moduleId;
    input currentState;
    input interoperableParamsNotFound;
    input usingPatternWriter;
    input usingPatternReader;
    input applyLaneReversal;
    input localFunctionalLanes;
    input txWidthChanged;
    input remoteFunctionalLanes;
    input rxWidthChanged;
  endclocking

  modport drv (clocking drv_cb, input clock, input reset);
  modport mon (clocking mon_cb, input clock, input reset);
endinterface

`endif
