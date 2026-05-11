`ifndef MBTRAIN_IF_SV
`define MBTRAIN_IF_SV

interface mbtrain_if(input logic clock, input logic reset);
  // FSM control
  logic        fsmCtrl_start;
  logic        fsmCtrl_substateTransitioning;
  logic        fsmCtrl_error;
  logic        fsmCtrl_done;

  // Control inputs (driven by TB)
  logic        goToState_valid;
  logic [1:0]  goToState_bits;
  logic [3:0]  negotiatedMaxDataRate;
  logic        pllLock;
  logic        phyInRetrain;
  logic        interpretBy8Lane;
  logic [15:0] maxErrorThresholdPerLane;
  logic        changeInRuntimeLinkCtrlRegs;
  logic [2:0]  currLocalTxFunctionalLanes;
  logic [2:0]  currRemoteTxFunctionalLanes;

  // Observed state outputs
  logic [3:0]  currentState;
  logic        freqSel_valid;
  logic [3:0]  freqSel_bits;
  logic        doElectricalIdleTx;
  logic        doElectricalIdleRx;
  logic        clearPhyInRetrainFlag;
  logic        txWidthChanged;
  logic        rxWidthChanged;
  logic [2:0]  newLocalFunctionalLanes;
  logic [2:0]  newRemoteFunctionalLanes;
  logic        rxClkCalSendFwClkPattern;
  logic        rxClkCalSendTrkPattern;

  // mbLaneCtrlIo (En polarity: 1=enabled/active, 0=disabled)
  logic [15:0] mbLaneCtrl_txDataEn;
  logic        mbLaneCtrl_txClkEn;
  logic        mbLaneCtrl_txValidEn;
  logic        mbLaneCtrl_txTrackEn;
  logic [15:0] mbLaneCtrl_rxDataEn;
  logic        mbLaneCtrl_rxClkEn;
  logic        mbLaneCtrl_rxValidEn;
  logic        mbLaneCtrl_rxTrackEn;

  // Requester SB lane
  logic         requesterSbLaneIo_tx_valid;
  logic [127:0] requesterSbLaneIo_tx_bits_data;
  logic         requesterSbLaneIo_tx_ready;
  logic         requesterSbLaneIo_rx_valid;
  logic [127:0] requesterSbLaneIo_rx_bits_data;
  logic         requesterSbLaneIo_rx_ready;

  // Responder SB lane
  logic         responderSbLaneIo_tx_valid;
  logic [127:0] responderSbLaneIo_tx_bits_data;
  logic         responderSbLaneIo_tx_ready;
  logic         responderSbLaneIo_rx_valid;
  logic [127:0] responderSbLaneIo_rx_bits_data;
  logic         responderSbLaneIo_rx_ready;

  // PhyLaneTrainer-facing training control
  logic        trainingCtrl_txSelfCalStart;
  logic        trainingCtrl_rxClkCalStart;
  logic        trainingCtrl_txSelfCalDone;
  logic        trainingCtrl_rxClkCalDone;
  logic        trainingCtrl_capableTest_isTxType;
  logic        trainingCtrl_capableTest_isRxType;
  logic [1:0]  trainingCtrl_capableTest_testKind;
  logic        trainingCtrl_req_readyForReq;
  logic        trainingCtrl_req_start;
  logic [1:0]  trainingCtrl_req_testKind;
  logic        trainingCtrl_req_complete;
  logic        trainingCtrl_resp_inProgress;
  logic        trainingCtrl_resp_done;
  logic        trainingCtrl_resp_results_valid;
  logic [15:0] trainingCtrl_resp_results_bits;
  logic        trainingCtrl_remoteRxSweepResults_valid;
  logic [15:0] trainingCtrl_remoteRxSweepResults_bits;

  // TxPtTest Requester stub (TB drives result inputs, DUT drives start/params)
  logic        txPtTestReq_done;
  logic        txPtTestReq_ptTestResults_valid;
  logic [15:0] txPtTestReq_ptTestResults_bits;
  logic        txPtTestReq_start;
  logic [3:0]  txPtTestReq_clockPhase;
  logic [2:0]  txPtTestReq_dataPattern;
  logic [2:0]  txPtTestReq_validPattern;
  logic        txPtTestReq_patternMode;
  logic [15:0] txPtTestReq_iterationCount;
  logic [15:0] txPtTestReq_idleCount;
  logic [15:0] txPtTestReq_burstCount;
  logic [15:0] txPtTestReq_maxErrorThreshold;
  logic        txPtTestReq_comparisonMode;
  logic [1:0]  txPtTestReq_patternType;

  // TxEyeSweep Requester stub
  logic        txEyeSweepReq_done;
  logic        txEyeSweepReq_eyeSweepTestResults_valid;
  logic [15:0] txEyeSweepReq_eyeSweepTestResults_bits;
  logic        txEyeSweepReq_start;
  logic [3:0]  txEyeSweepReq_clockPhase;
  logic [2:0]  txEyeSweepReq_dataPattern;
  logic [2:0]  txEyeSweepReq_validPattern;
  logic        txEyeSweepReq_patternMode;
  logic [15:0] txEyeSweepReq_iterationCount;
  logic [15:0] txEyeSweepReq_idleCount;
  logic [15:0] txEyeSweepReq_burstCount;
  logic [15:0] txEyeSweepReq_maxErrorThreshold;
  logic        txEyeSweepReq_comparisonMode;
  logic [1:0]  txEyeSweepReq_patternType;

  // RxPtTest Requester stub
  logic        rxPtTestReq_done;
  logic        rxPtTestReq_ptTestResults_valid;
  logic [15:0] rxPtTestReq_ptTestResults_bits;
  logic        rxPtTestReq_start;
  logic [3:0]  rxPtTestReq_clockPhase;
  logic [2:0]  rxPtTestReq_dataPattern;
  logic [2:0]  rxPtTestReq_validPattern;
  logic        rxPtTestReq_patternMode;
  logic [15:0] rxPtTestReq_iterationCount;
  logic [15:0] rxPtTestReq_idleCount;
  logic [15:0] rxPtTestReq_burstCount;
  logic [15:0] rxPtTestReq_maxErrorThreshold;
  logic        rxPtTestReq_comparisonMode;
  logic [1:0]  rxPtTestReq_patternType;

  // RxEyeSweep Requester stub
  logic        rxEyeSweepReq_done;
  logic        rxEyeSweepReq_eyeSweepTestResults_valid;
  logic [15:0] rxEyeSweepReq_eyeSweepTestResults_bits;
  logic        rxEyeSweepReq_start;
  logic [3:0]  rxEyeSweepReq_clockPhase;
  logic [2:0]  rxEyeSweepReq_dataPattern;
  logic [2:0]  rxEyeSweepReq_validPattern;
  logic        rxEyeSweepReq_patternMode;
  logic [15:0] rxEyeSweepReq_iterationCount;
  logic [15:0] rxEyeSweepReq_idleCount;
  logic [15:0] rxEyeSweepReq_burstCount;
  logic [15:0] rxEyeSweepReq_maxErrorThreshold;
  logic        rxEyeSweepReq_comparisonMode;
  logic [1:0]  rxEyeSweepReq_patternType;

  // Responder stubs (TB drives done/results, DUT drives start/pattern type)
  logic        txPtTestResp_done;
  logic        txPtTestResp_start;
  logic [1:0]  txPtTestResp_patternType;
  logic        txEyeSweepResp_done;
  logic        txEyeSweepResp_start;
  logic [1:0]  txEyeSweepResp_patternType;
  logic        rxPtTestResp_done;
  logic        rxPtTestResp_start;
  logic [1:0]  rxPtTestResp_patternType;
  logic        rxEyeSweepResp_done;
  logic        rxEyeSweepResp_start;
  logic [1:0]  rxEyeSweepResp_patternType;
  logic        rxEyeSweepResp_remoteEyeSweepTestResults_valid;
  logic [15:0] rxEyeSweepResp_remoteEyeSweepTestResults_bits;

endinterface
`endif
