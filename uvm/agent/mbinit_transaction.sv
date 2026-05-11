`ifndef MBINIT_TRANSACTION_SV
`define MBINIT_TRANSACTION_SV

// Extends logphy_transaction, inheriting:
//   start_fsm, delay, hold_cycles
//   rx_valid / rx_data       → requester SB RX (req_rx)
//   rsp_rx_valid / rsp_rx_data → responder SB RX
//   tx_valid / tx_data       → observed requester SB TX
//   rsp_tx_valid / rsp_tx_data → observed responder SB TX
//   fsm_done, fsm_error
class mbinit_transaction extends logphy_transaction;

  // --- Additional MBINIT stimulus ---
  // Local PHY settings
  rand logic [4:0]  local_voltageSwing;
  rand logic [3:0]  local_maxDataRate;
  rand logic        local_clockMode;
  rand logic        local_clockPhase;
  rand logic        local_sbFeatExt;
  rand logic        local_txAdjRuntime;
  rand logic [1:0]  local_moduleId;

  // Calibration done (driver pulses this; also auto-stubbed on mbInitCalStart)
  rand logic        mbInitCalDone;

  // PatternReader result (TB simulates; all lanes pass by default)
  rand logic [15:0] patternReader_perLaneStatusBits;
  rand logic        patternReader_aggregateStatus;

  // --- Additional MBINIT observations ---
  logic [2:0]  currentState;
  logic        negotiatedPhySettings_valid;
  logic [3:0]  negotiated_maxDataRate;
  logic        negotiated_clockMode;
  logic        interoperableParamsNotFound;
  logic        applyLaneReversal;

  // Pattern IO observations (XC-09/10, RC-02, RV-03, LR-02, RM-01)
  logic        usingPatternWriter;
  logic        usingPatternReader;
  logic        patternWriter_req_valid;
  logic [1:0]  patternWriter_patternType;
  logic        patternReader_req_valid;
  logic [1:0]  patternReader_patternType;
  logic        txPtTest_start;

  // Lane control observations (XC-05)
  logic [15:0] mbLaneCtrl_txDataTriState;
  logic        mbLaneCtrl_txClkTriState;
  logic        mbLaneCtrl_txValidTriState;
  logic        mbLaneCtrl_txTrackTriState;
  logic [15:0] mbLaneCtrl_rxDataEn;
  logic        mbLaneCtrl_rxClkEn;
  logic        mbLaneCtrl_rxValidEn;
  logic        mbLaneCtrl_rxTrackEn;

  `uvm_object_utils_begin(mbinit_transaction)
    `uvm_field_int(local_voltageSwing,              UVM_ALL_ON)
    `uvm_field_int(local_maxDataRate,               UVM_ALL_ON)
    `uvm_field_int(local_clockMode,                 UVM_ALL_ON)
    `uvm_field_int(local_clockPhase,                UVM_ALL_ON)
    `uvm_field_int(local_sbFeatExt,                 UVM_ALL_ON)
    `uvm_field_int(local_txAdjRuntime,              UVM_ALL_ON)
    `uvm_field_int(local_moduleId,                  UVM_ALL_ON)
    `uvm_field_int(mbInitCalDone,                   UVM_ALL_ON)
    `uvm_field_int(patternReader_perLaneStatusBits, UVM_ALL_ON)
    `uvm_field_int(patternReader_aggregateStatus,   UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "mbinit_transaction");
    super.new(name);
    // PHY defaults: max data rate, clock mode 1, everything else 0
    local_voltageSwing              = 5'h1F;
    local_maxDataRate               = 4'hF;
    local_clockMode                 = 1;
    local_clockPhase                = 0;
    local_sbFeatExt                 = 0;
    local_txAdjRuntime              = 0;
    local_moduleId                  = 0;
    mbInitCalDone                   = 0;
    patternReader_perLaneStatusBits = 16'hFFFF; // all lanes pass
    patternReader_aggregateStatus   = 1;
  endfunction

endclass
`endif
