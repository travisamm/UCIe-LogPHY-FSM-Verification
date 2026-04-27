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
  logic [2:0]  negotiatedMaxDataRate;
  logic        pllLock;
  logic        mbTrainTxSelfCalDone;
  logic        mbTrainRxClkCalDone;
  logic        phyInRetrain;
  logic        interpretBy8Lane;
  logic [15:0] maxErrorThresholdPerLane;
  logic        changeInRuntimeLinkCtrlRegs;
  logic [2:0]  currLocalTxFunctionalLanes;
  logic [2:0]  currRemoteTxFunctionalLanes;

  // Observed state outputs
  logic [3:0]  currentState;
  logic        freqSel_valid;
  logic [2:0]  freqSel_bits;
  logic        mbTrainTxSelfCalStart;
  logic        mbTrainRxClkCalStart;
  logic        doElectricalIdleTx;
  logic        doElectricalIdleRx;
  logic        clearPhyInRetrainFlag;
  logic        txWidthChanged;
  logic        rxWidthChanged;
  logic [2:0]  newLocalFunctionalLanes;
  logic [2:0]  newRemoteFunctionalLanes;
  logic        rxClkCalSendFwClkPattern;
  logic        rxClkCalSendTrkPattern;

  // mbLaneCtrlIo (packed buses, observed only)
  logic [15:0] mbLaneCtrl_txDataTriState;
  logic        mbLaneCtrl_txClkTriState;
  logic        mbLaneCtrl_txValidTriState;
  logic        mbLaneCtrl_txTrackTriState;
  logic [15:0] mbLaneCtrl_rxDataEn;
  logic        mbLaneCtrl_rxClkEn;
  logic        mbLaneCtrl_rxValidEn;
  logic        mbLaneCtrl_rxTrackEn;

  // Requester SB lane
  logic        requesterSbLaneIo_tx_valid;
  logic [127:0] requesterSbLaneIo_tx_bits_data;
  logic        requesterSbLaneIo_tx_ready;
  logic        requesterSbLaneIo_rx_valid;
  logic [127:0] requesterSbLaneIo_rx_bits_data;
  logic        requesterSbLaneIo_rx_ready;

  // Responder SB lane
  logic        responderSbLaneIo_tx_valid;
  logic [127:0] responderSbLaneIo_tx_bits_data;
  logic        responderSbLaneIo_tx_ready;
  logic        responderSbLaneIo_rx_valid;
  logic [127:0] responderSbLaneIo_rx_bits_data;
  logic        responderSbLaneIo_rx_ready;

  // TxPtTest Requester stub (TB drives result inputs, DUT drives start)
  logic        txPtTestReq_done;
  logic        txPtTestReq_ptTestResults_valid;
  logic [15:0] txPtTestReq_ptTestResults_bits;
  logic        txPtTestReq_start;

  // TxEyeSweep Requester stub
  logic        txEyeSweepReq_done;
  logic        txEyeSweepReq_eyeSweepTestResults_valid;
  logic [15:0] txEyeSweepReq_eyeSweepTestResults_bits;
  logic        txEyeSweepReq_start;

  // RxPtTest Requester stub
  logic        rxPtTestReq_done;
  logic        rxPtTestReq_ptTestResults_valid;
  logic [15:0] rxPtTestReq_ptTestResults_bits;
  logic        rxPtTestReq_start;

  // RxEyeSweep Requester stub
  logic        rxEyeSweepReq_done;
  logic        rxEyeSweepReq_eyeSweepTestResults_valid;
  logic [15:0] rxEyeSweepReq_eyeSweepTestResults_bits;
  logic        rxEyeSweepReq_start;

  // Responder stubs (TB drives done, DUT drives start)
  logic        txPtTestResp_done;
  logic        txPtTestResp_start;
  logic        txEyeSweepResp_done;
  logic        txEyeSweepResp_start;
  logic        rxPtTestResp_done;
  logic        rxPtTestResp_start;
  logic        rxEyeSweepResp_done;
  logic        rxEyeSweepResp_start;

endinterface
`endif
