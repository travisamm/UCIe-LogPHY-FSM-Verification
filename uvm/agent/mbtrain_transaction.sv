`ifndef MBTRAIN_TRANSACTION_SV
`define MBTRAIN_TRANSACTION_SV

// Extends logphy_transaction, inheriting:
//   start_fsm, delay, hold_cycles
//   rx_valid / rx_data         -> requester SB RX
//   rsp_rx_valid / rsp_rx_data -> responder SB RX
//   tx_valid / tx_data         -> observed requester SB TX
//   rsp_tx_valid / rsp_tx_data -> observed responder SB TX
//   fsm_done, fsm_error
class mbtrain_transaction extends logphy_transaction;

  // --- Additional MBTrain stimulus ---
  rand logic        pllLock;
  rand logic        goToState_valid;
  rand logic [1:0]  goToState_bits;
  rand logic [3:0]  negotiatedMaxDataRate;
  rand logic        phyInRetrain;
  rand logic        interpretBy8Lane;
  rand logic [15:0] maxErrorThresholdPerLane;
  rand logic        changeInRuntimeLinkCtrlRegs;
  rand logic [2:0]  currLocalTxFunctionalLanes;
  rand logic [2:0]  currRemoteTxFunctionalLanes;

  // PhyLaneTrainer-side controls driven by TB.
  rand logic        trainingReqStart;
  rand logic [1:0]  trainingReqTestKind;
  rand logic        trainingReqComplete;
  rand logic        trainingTxSelfCalDone;
  rand logic        trainingRxClkCalDone;

  // Test result stubs (all-pass by default)
  rand logic [15:0] ptTestResults_bits;
  rand logic [15:0] eyeSweepTestResults_bits;

  // --- Additional MBTrain observations ---
  logic [3:0] currentState;
  logic       freqSel_valid;
  logic [3:0] freqSel_bits;
  logic       trainingTxSelfCalStart;
  logic       trainingRxClkCalStart;
  logic       doElectricalIdleTx;
  logic       doElectricalIdleRx;

  logic       trainingCapableIsTxType;
  logic       trainingCapableIsRxType;
  logic [1:0] trainingCapableTestKind;
  logic       trainingReqReadyForReq;
  logic       trainingRespInProgress;
  logic       trainingRespDone;
  logic       trainingRespResultsValid;
  logic [15:0] trainingRespResultsBits;
  logic       trainingRemoteRxSweepResultsValid;
  logic [15:0] trainingRemoteRxSweepResultsBits;

  // Requester link-op observations used by VALVREF/DATAVREF checks.
  logic       rxPtTestReq_start;
  logic [3:0] rxPtTestReq_clockPhase;
  logic [2:0] rxPtTestReq_dataPattern;
  logic [2:0] rxPtTestReq_validPattern;
  logic       rxPtTestReq_patternMode;
  logic [15:0] rxPtTestReq_iterationCount;
  logic [15:0] rxPtTestReq_idleCount;
  logic [15:0] rxPtTestReq_burstCount;
  logic [15:0] rxPtTestReq_maxErrorThreshold;
  logic       rxPtTestReq_comparisonMode;
  logic [1:0] rxPtTestReq_patternType;

  logic       rxEyeSweepReq_start;
  logic [3:0] rxEyeSweepReq_clockPhase;
  logic [2:0] rxEyeSweepReq_dataPattern;
  logic [2:0] rxEyeSweepReq_validPattern;
  logic       rxEyeSweepReq_patternMode;
  logic [15:0] rxEyeSweepReq_iterationCount;
  logic [15:0] rxEyeSweepReq_idleCount;
  logic [15:0] rxEyeSweepReq_burstCount;
  logic [15:0] rxEyeSweepReq_maxErrorThreshold;
  logic       rxEyeSweepReq_comparisonMode;
  logic [1:0] rxEyeSweepReq_patternType;

  logic       rxPtTestResp_start;
  logic [1:0] rxPtTestResp_patternType;
  logic       rxEyeSweepResp_start;
  logic [1:0] rxEyeSweepResp_patternType;

  // Lane control observations (XC-05)
  logic [15:0] mbLaneCtrl_txDataEn;
  logic        mbLaneCtrl_txClkEn;
  logic        mbLaneCtrl_txValidEn;
  logic        mbLaneCtrl_txTrackEn;
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
    `uvm_field_int(trainingReqStart,           UVM_ALL_ON)
    `uvm_field_int(trainingReqTestKind,        UVM_ALL_ON)
    `uvm_field_int(trainingReqComplete,        UVM_ALL_ON)
    `uvm_field_int(trainingTxSelfCalDone,      UVM_ALL_ON)
    `uvm_field_int(trainingRxClkCalDone,       UVM_ALL_ON)
    `uvm_field_int(ptTestResults_bits,         UVM_ALL_ON)
    `uvm_field_int(eyeSweepTestResults_bits,   UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "mbtrain_transaction");
    super.new(name);
    pllLock                     = 1;
    goToState_valid             = 0;
    goToState_bits              = 0;
    negotiatedMaxDataRate       = 4'h3;   // speed16 default
    phyInRetrain                = 0;
    interpretBy8Lane            = 0;
    maxErrorThresholdPerLane    = 16'hFFFF;
    changeInRuntimeLinkCtrlRegs = 0;
    currLocalTxFunctionalLanes  = 3'h7;
    currRemoteTxFunctionalLanes = 3'h7;
    trainingReqStart            = 0;
    trainingReqTestKind         = 2'h0;   // PointTest
    trainingReqComplete         = 0;
    trainingTxSelfCalDone       = 0;
    trainingRxClkCalDone        = 0;
    ptTestResults_bits          = 16'hFFFF;
    eyeSweepTestResults_bits    = 16'hFFFF;
  endfunction

endclass
`endif
