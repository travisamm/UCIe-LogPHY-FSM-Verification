`ifndef MBTRAIN_TRANSACTION_SV
`define MBTRAIN_TRANSACTION_SV

// Extends logphy_transaction, inheriting:
//   start_fsm, delay, hold_cycles
//   rx_valid / rx_data         → requester SB RX (req_rx)
//   rsp_rx_valid / rsp_rx_data → responder SB RX
//   tx_valid / tx_data         → observed requester SB TX
//   rsp_tx_valid / rsp_tx_data → observed responder SB TX
//   fsm_done, fsm_error
class mbtrain_transaction extends logphy_transaction;

  // --- Additional MBTrain stimulus ---
  rand logic        pllLock;
  rand logic        goToState_valid;
  rand logic [1:0]  goToState_bits;
  rand logic [2:0]  negotiatedMaxDataRate;
  rand logic        phyInRetrain;
  rand logic        interpretBy8Lane;
  rand logic [15:0] maxErrorThresholdPerLane;
  rand logic        changeInRuntimeLinkCtrlRegs;
  rand logic [2:0]  currLocalTxFunctionalLanes;
  rand logic [2:0]  currRemoteTxFunctionalLanes;

  // Cal done responses (driver also auto-stubs these)
  rand logic        mbTrainTxSelfCalDone;
  rand logic        mbTrainRxClkCalDone;

  // Test result stubs (all-pass by default)
  rand logic [15:0] ptTestResults_bits;
  rand logic [15:0] eyeSweepTestResults_bits;

  // --- Additional MBTrain observations ---
  logic [3:0] currentState;
  logic       freqSel_valid;
  logic [2:0] freqSel_bits;
  logic       mbTrainTxSelfCalStart;
  logic       mbTrainRxClkCalStart;
  logic       doElectricalIdleTx;
  logic       doElectricalIdleRx;

  // Lane control observations (XC-05)
  logic [15:0] mbLaneCtrl_txDataTriState;
  logic        mbLaneCtrl_txClkTriState;
  logic        mbLaneCtrl_txValidTriState;
  logic        mbLaneCtrl_txTrackTriState;
  logic [15:0] mbLaneCtrl_rxDataEn;
  logic        mbLaneCtrl_rxClkEn;
  logic        mbLaneCtrl_rxValidEn;
  logic        mbLaneCtrl_rxTrackEn;

  `uvm_object_utils_begin(mbtrain_transaction)
    `uvm_field_int(pllLock,                    UVM_ALL_ON)
    `uvm_field_int(goToState_valid,            UVM_ALL_ON)
    `uvm_field_int(goToState_bits,             UVM_ALL_ON)
    `uvm_field_int(negotiatedMaxDataRate,      UVM_ALL_ON)
    `uvm_field_int(phyInRetrain,               UVM_ALL_ON)
    `uvm_field_int(interpretBy8Lane,           UVM_ALL_ON)
    `uvm_field_int(maxErrorThresholdPerLane,   UVM_ALL_ON)
    `uvm_field_int(changeInRuntimeLinkCtrlRegs,UVM_ALL_ON)
    `uvm_field_int(currLocalTxFunctionalLanes, UVM_ALL_ON)
    `uvm_field_int(currRemoteTxFunctionalLanes,UVM_ALL_ON)
    `uvm_field_int(mbTrainTxSelfCalDone,       UVM_ALL_ON)
    `uvm_field_int(mbTrainRxClkCalDone,        UVM_ALL_ON)
    `uvm_field_int(ptTestResults_bits,         UVM_ALL_ON)
    `uvm_field_int(eyeSweepTestResults_bits,   UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "mbtrain_transaction");
    super.new(name);
    pllLock                    = 1;
    goToState_valid            = 0;
    goToState_bits             = 0;
    negotiatedMaxDataRate      = 3'h3;   // highest supported rate
    phyInRetrain               = 0;
    interpretBy8Lane           = 0;
    maxErrorThresholdPerLane   = 16'hFFFF;
    changeInRuntimeLinkCtrlRegs = 0;
    currLocalTxFunctionalLanes  = 3'h7;
    currRemoteTxFunctionalLanes = 3'h7;
    mbTrainTxSelfCalDone        = 0;
    mbTrainRxClkCalDone         = 0;
    ptTestResults_bits          = 16'hFFFF;  // all lanes pass
    eyeSweepTestResults_bits    = 16'hFFFF;
  endfunction

endclass
`endif
