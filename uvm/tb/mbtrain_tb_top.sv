`timescale 1ns/1ps

module mbtrain_tb_top;
  import uvm_pkg::*;
  import mbtrain_env_pkg::*;
  import mbtrain_seq_pkg::*;
  import mbtrain_test_pkg::*;

  logic clock;
  logic reset;

  initial begin clock = 0; forever #5 clock = ~clock; end
  initial begin reset = 1; #20 reset = 0; end

  mbtrain_if vif(clock, reset);

  // Dummy wires for DUT mbLaneCtrlIo outputs (not monitored by TB)
  wire [15:0] mbLane_txDataTriState;
  wire        mbLane_txClkTriState, mbLane_txValidTriState, mbLane_txTrackTriState;
  wire [15:0] mbLane_rxDataEn;
  wire        mbLane_rxClkEn, mbLane_rxValidEn, mbLane_rxTrackEn;

  MBTrainSM dut (
    .clock  (clock),
    .reset  (reset),

    // Control inputs
    .io_goToState_valid              (vif.goToState_valid),
    .io_goToState_bits               (vif.goToState_bits),
    .io_negotiatedMaxDataRate        (vif.negotiatedMaxDataRate),
    .io_pllLock                      (vif.pllLock),
    .io_mbTrainTxSelfCalDone         (vif.mbTrainTxSelfCalDone),
    .io_mbTrainRxClkCalDone          (vif.mbTrainRxClkCalDone),
    .io_phyInRetrain                 (vif.phyInRetrain),
    .io_interpretBy8Lane             (vif.interpretBy8Lane),
    .io_maxErrorThresholdPerLane     (vif.maxErrorThresholdPerLane),
    .io_changeInRuntimeLinkCtrlRegs  (vif.changeInRuntimeLinkCtrlRegs),
    .io_currLocalTxFunctionalLanes   (vif.currLocalTxFunctionalLanes),
    .io_currRemoteTxFunctionalLanes  (vif.currRemoteTxFunctionalLanes),

    // FSM control
    .io_fsmCtrl_start                (vif.fsmCtrl_start),
    .io_fsmCtrl_substateTransitioning(vif.fsmCtrl_substateTransitioning),
    .io_fsmCtrl_error                (vif.fsmCtrl_error),
    .io_fsmCtrl_done                 (vif.fsmCtrl_done),

    // State outputs
    .io_currentState                 (vif.currentState),
    .io_freqSel_valid                (vif.freqSel_valid),
    .io_freqSel_bits                 (vif.freqSel_bits),
    .io_mbTrainTxSelfCalStart        (vif.mbTrainTxSelfCalStart),
    .io_mbTrainRxClkCalStart         (vif.mbTrainRxClkCalStart),
    .io_doElectricalIdleTx           (vif.doElectricalIdleTx),
    .io_doElectricalIdleRx           (vif.doElectricalIdleRx),
    .io_clearPhyInRetrainFlag        (vif.clearPhyInRetrainFlag),
    .io_txWidthChanged               (vif.txWidthChanged),
    .io_rxWidthChanged               (vif.rxWidthChanged),
    .io_newLocalFunctionalLanes      (vif.newLocalFunctionalLanes),
    .io_newRemoteFunctionalLanes     (vif.newRemoteFunctionalLanes),
    .io_rxClkCalSendFwClkPattern     (vif.rxClkCalSendFwClkPattern),
    .io_rxClkCalSendTrkPattern       (vif.rxClkCalSendTrkPattern),

    // mbLaneCtrlIo outputs → interface (observed) and dummy wires
    .io_mbLaneCtrlIo_txDataTriState_0  (mbLane_txDataTriState[0]),
    .io_mbLaneCtrlIo_txDataTriState_1  (mbLane_txDataTriState[1]),
    .io_mbLaneCtrlIo_txDataTriState_2  (mbLane_txDataTriState[2]),
    .io_mbLaneCtrlIo_txDataTriState_3  (mbLane_txDataTriState[3]),
    .io_mbLaneCtrlIo_txDataTriState_4  (mbLane_txDataTriState[4]),
    .io_mbLaneCtrlIo_txDataTriState_5  (mbLane_txDataTriState[5]),
    .io_mbLaneCtrlIo_txDataTriState_6  (mbLane_txDataTriState[6]),
    .io_mbLaneCtrlIo_txDataTriState_7  (mbLane_txDataTriState[7]),
    .io_mbLaneCtrlIo_txDataTriState_8  (mbLane_txDataTriState[8]),
    .io_mbLaneCtrlIo_txDataTriState_9  (mbLane_txDataTriState[9]),
    .io_mbLaneCtrlIo_txDataTriState_10 (mbLane_txDataTriState[10]),
    .io_mbLaneCtrlIo_txDataTriState_11 (mbLane_txDataTriState[11]),
    .io_mbLaneCtrlIo_txDataTriState_12 (mbLane_txDataTriState[12]),
    .io_mbLaneCtrlIo_txDataTriState_13 (mbLane_txDataTriState[13]),
    .io_mbLaneCtrlIo_txDataTriState_14 (mbLane_txDataTriState[14]),
    .io_mbLaneCtrlIo_txDataTriState_15 (mbLane_txDataTriState[15]),
    .io_mbLaneCtrlIo_txClkTriState     (mbLane_txClkTriState),
    .io_mbLaneCtrlIo_txValidTriState   (mbLane_txValidTriState),
    .io_mbLaneCtrlIo_txTrackTriState   (mbLane_txTrackTriState),
    .io_mbLaneCtrlIo_rxDataEn_0  (mbLane_rxDataEn[0]),
    .io_mbLaneCtrlIo_rxDataEn_1  (mbLane_rxDataEn[1]),
    .io_mbLaneCtrlIo_rxDataEn_2  (mbLane_rxDataEn[2]),
    .io_mbLaneCtrlIo_rxDataEn_3  (mbLane_rxDataEn[3]),
    .io_mbLaneCtrlIo_rxDataEn_4  (mbLane_rxDataEn[4]),
    .io_mbLaneCtrlIo_rxDataEn_5  (mbLane_rxDataEn[5]),
    .io_mbLaneCtrlIo_rxDataEn_6  (mbLane_rxDataEn[6]),
    .io_mbLaneCtrlIo_rxDataEn_7  (mbLane_rxDataEn[7]),
    .io_mbLaneCtrlIo_rxDataEn_8  (mbLane_rxDataEn[8]),
    .io_mbLaneCtrlIo_rxDataEn_9  (mbLane_rxDataEn[9]),
    .io_mbLaneCtrlIo_rxDataEn_10 (mbLane_rxDataEn[10]),
    .io_mbLaneCtrlIo_rxDataEn_11 (mbLane_rxDataEn[11]),
    .io_mbLaneCtrlIo_rxDataEn_12 (mbLane_rxDataEn[12]),
    .io_mbLaneCtrlIo_rxDataEn_13 (mbLane_rxDataEn[13]),
    .io_mbLaneCtrlIo_rxDataEn_14 (mbLane_rxDataEn[14]),
    .io_mbLaneCtrlIo_rxDataEn_15 (mbLane_rxDataEn[15]),
    .io_mbLaneCtrlIo_rxClkEn     (mbLane_rxClkEn),
    .io_mbLaneCtrlIo_rxValidEn   (mbLane_rxValidEn),
    .io_mbLaneCtrlIo_rxTrackEn   (mbLane_rxTrackEn),

    // Requester SB lane
    .io_requesterSbLaneIo_tx_ready     (vif.requesterSbLaneIo_tx_ready),
    .io_requesterSbLaneIo_tx_valid     (vif.requesterSbLaneIo_tx_valid),
    .io_requesterSbLaneIo_tx_bits_data (vif.requesterSbLaneIo_tx_bits_data),
    .io_requesterSbLaneIo_rx_ready     (vif.requesterSbLaneIo_rx_ready),
    .io_requesterSbLaneIo_rx_valid     (vif.requesterSbLaneIo_rx_valid),
    .io_requesterSbLaneIo_rx_bits_data (vif.requesterSbLaneIo_rx_bits_data),

    // Responder SB lane
    .io_responderSbLaneIo_tx_ready     (vif.responderSbLaneIo_tx_ready),
    .io_responderSbLaneIo_tx_valid     (vif.responderSbLaneIo_tx_valid),
    .io_responderSbLaneIo_tx_bits_data (vif.responderSbLaneIo_tx_bits_data),
    .io_responderSbLaneIo_rx_ready     (vif.responderSbLaneIo_rx_ready),
    .io_responderSbLaneIo_rx_valid     (vif.responderSbLaneIo_rx_valid),
    .io_responderSbLaneIo_rx_bits_data (vif.responderSbLaneIo_rx_bits_data),

    // TxPtTest Requester
    .io_txPtTestReqIntfIo_done                         (vif.txPtTestReq_done),
    .io_txPtTestReqIntfIo_ptTestResults_valid          (vif.txPtTestReq_ptTestResults_valid),
    .io_txPtTestReqIntfIo_ptTestResults_bits_0         (vif.txPtTestReq_ptTestResults_bits[0]),
    .io_txPtTestReqIntfIo_ptTestResults_bits_1         (vif.txPtTestReq_ptTestResults_bits[1]),
    .io_txPtTestReqIntfIo_ptTestResults_bits_2         (vif.txPtTestReq_ptTestResults_bits[2]),
    .io_txPtTestReqIntfIo_ptTestResults_bits_3         (vif.txPtTestReq_ptTestResults_bits[3]),
    .io_txPtTestReqIntfIo_ptTestResults_bits_4         (vif.txPtTestReq_ptTestResults_bits[4]),
    .io_txPtTestReqIntfIo_ptTestResults_bits_5         (vif.txPtTestReq_ptTestResults_bits[5]),
    .io_txPtTestReqIntfIo_ptTestResults_bits_6         (vif.txPtTestReq_ptTestResults_bits[6]),
    .io_txPtTestReqIntfIo_ptTestResults_bits_7         (vif.txPtTestReq_ptTestResults_bits[7]),
    .io_txPtTestReqIntfIo_ptTestResults_bits_8         (vif.txPtTestReq_ptTestResults_bits[8]),
    .io_txPtTestReqIntfIo_ptTestResults_bits_9         (vif.txPtTestReq_ptTestResults_bits[9]),
    .io_txPtTestReqIntfIo_ptTestResults_bits_10        (vif.txPtTestReq_ptTestResults_bits[10]),
    .io_txPtTestReqIntfIo_ptTestResults_bits_11        (vif.txPtTestReq_ptTestResults_bits[11]),
    .io_txPtTestReqIntfIo_ptTestResults_bits_12        (vif.txPtTestReq_ptTestResults_bits[12]),
    .io_txPtTestReqIntfIo_ptTestResults_bits_13        (vif.txPtTestReq_ptTestResults_bits[13]),
    .io_txPtTestReqIntfIo_ptTestResults_bits_14        (vif.txPtTestReq_ptTestResults_bits[14]),
    .io_txPtTestReqIntfIo_ptTestResults_bits_15        (vif.txPtTestReq_ptTestResults_bits[15]),
    .io_txPtTestReqIntfIo_start                        (vif.txPtTestReq_start),
    .io_txPtTestReqIntfIo_linkTrainingParameters_clockPhase    (),
    .io_txPtTestReqIntfIo_linkTrainingParameters_dataPattern   (),
    .io_txPtTestReqIntfIo_linkTrainingParameters_validPattern  (),
    .io_txPtTestReqIntfIo_linkTrainingParameters_patternMode   (),
    .io_txPtTestReqIntfIo_linkTrainingParameters_iterationCount(),
    .io_txPtTestReqIntfIo_linkTrainingParameters_idleCount     (),
    .io_txPtTestReqIntfIo_linkTrainingParameters_burstCount    (),
    .io_txPtTestReqIntfIo_linkTrainingParameters_maxErrorThreshold(),
    .io_txPtTestReqIntfIo_linkTrainingParameters_comparisonMode(),
    .io_txPtTestReqIntfIo_patternType                          (),

    // TxEyeSweep Requester
    .io_txEyeSweepReqIntfIo_done                        (vif.txEyeSweepReq_done),
    .io_txEyeSweepReqIntfIo_eyeSweepTestResults_valid   (vif.txEyeSweepReq_eyeSweepTestResults_valid),
    .io_txEyeSweepReqIntfIo_eyeSweepTestResults_bits_0  (vif.txEyeSweepReq_eyeSweepTestResults_bits[0]),
    .io_txEyeSweepReqIntfIo_eyeSweepTestResults_bits_1  (vif.txEyeSweepReq_eyeSweepTestResults_bits[1]),
    .io_txEyeSweepReqIntfIo_eyeSweepTestResults_bits_2  (vif.txEyeSweepReq_eyeSweepTestResults_bits[2]),
    .io_txEyeSweepReqIntfIo_eyeSweepTestResults_bits_3  (vif.txEyeSweepReq_eyeSweepTestResults_bits[3]),
    .io_txEyeSweepReqIntfIo_eyeSweepTestResults_bits_4  (vif.txEyeSweepReq_eyeSweepTestResults_bits[4]),
    .io_txEyeSweepReqIntfIo_eyeSweepTestResults_bits_5  (vif.txEyeSweepReq_eyeSweepTestResults_bits[5]),
    .io_txEyeSweepReqIntfIo_eyeSweepTestResults_bits_6  (vif.txEyeSweepReq_eyeSweepTestResults_bits[6]),
    .io_txEyeSweepReqIntfIo_eyeSweepTestResults_bits_7  (vif.txEyeSweepReq_eyeSweepTestResults_bits[7]),
    .io_txEyeSweepReqIntfIo_eyeSweepTestResults_bits_8  (vif.txEyeSweepReq_eyeSweepTestResults_bits[8]),
    .io_txEyeSweepReqIntfIo_eyeSweepTestResults_bits_9  (vif.txEyeSweepReq_eyeSweepTestResults_bits[9]),
    .io_txEyeSweepReqIntfIo_eyeSweepTestResults_bits_10 (vif.txEyeSweepReq_eyeSweepTestResults_bits[10]),
    .io_txEyeSweepReqIntfIo_eyeSweepTestResults_bits_11 (vif.txEyeSweepReq_eyeSweepTestResults_bits[11]),
    .io_txEyeSweepReqIntfIo_eyeSweepTestResults_bits_12 (vif.txEyeSweepReq_eyeSweepTestResults_bits[12]),
    .io_txEyeSweepReqIntfIo_eyeSweepTestResults_bits_13 (vif.txEyeSweepReq_eyeSweepTestResults_bits[13]),
    .io_txEyeSweepReqIntfIo_eyeSweepTestResults_bits_14 (vif.txEyeSweepReq_eyeSweepTestResults_bits[14]),
    .io_txEyeSweepReqIntfIo_eyeSweepTestResults_bits_15 (vif.txEyeSweepReq_eyeSweepTestResults_bits[15]),
    .io_txEyeSweepReqIntfIo_start                        (vif.txEyeSweepReq_start),
    .io_txEyeSweepReqIntfIo_linkTrainingParameters_clockPhase    (),
    .io_txEyeSweepReqIntfIo_linkTrainingParameters_dataPattern   (),
    .io_txEyeSweepReqIntfIo_linkTrainingParameters_validPattern  (),
    .io_txEyeSweepReqIntfIo_linkTrainingParameters_patternMode   (),
    .io_txEyeSweepReqIntfIo_linkTrainingParameters_iterationCount(),
    .io_txEyeSweepReqIntfIo_linkTrainingParameters_idleCount     (),
    .io_txEyeSweepReqIntfIo_linkTrainingParameters_burstCount    (),
    .io_txEyeSweepReqIntfIo_linkTrainingParameters_maxErrorThreshold(),
    .io_txEyeSweepReqIntfIo_linkTrainingParameters_comparisonMode(),
    .io_txEyeSweepReqIntfIo_patternType                          (),

    // RxPtTest Requester
    .io_rxPtTestReqIntfIo_done                         (vif.rxPtTestReq_done),
    .io_rxPtTestReqIntfIo_ptTestResults_valid          (vif.rxPtTestReq_ptTestResults_valid),
    .io_rxPtTestReqIntfIo_ptTestResults_bits_0         (vif.rxPtTestReq_ptTestResults_bits[0]),
    .io_rxPtTestReqIntfIo_ptTestResults_bits_1         (vif.rxPtTestReq_ptTestResults_bits[1]),
    .io_rxPtTestReqIntfIo_ptTestResults_bits_2         (vif.rxPtTestReq_ptTestResults_bits[2]),
    .io_rxPtTestReqIntfIo_ptTestResults_bits_3         (vif.rxPtTestReq_ptTestResults_bits[3]),
    .io_rxPtTestReqIntfIo_ptTestResults_bits_4         (vif.rxPtTestReq_ptTestResults_bits[4]),
    .io_rxPtTestReqIntfIo_ptTestResults_bits_5         (vif.rxPtTestReq_ptTestResults_bits[5]),
    .io_rxPtTestReqIntfIo_ptTestResults_bits_6         (vif.rxPtTestReq_ptTestResults_bits[6]),
    .io_rxPtTestReqIntfIo_ptTestResults_bits_7         (vif.rxPtTestReq_ptTestResults_bits[7]),
    .io_rxPtTestReqIntfIo_ptTestResults_bits_8         (vif.rxPtTestReq_ptTestResults_bits[8]),
    .io_rxPtTestReqIntfIo_ptTestResults_bits_9         (vif.rxPtTestReq_ptTestResults_bits[9]),
    .io_rxPtTestReqIntfIo_ptTestResults_bits_10        (vif.rxPtTestReq_ptTestResults_bits[10]),
    .io_rxPtTestReqIntfIo_ptTestResults_bits_11        (vif.rxPtTestReq_ptTestResults_bits[11]),
    .io_rxPtTestReqIntfIo_ptTestResults_bits_12        (vif.rxPtTestReq_ptTestResults_bits[12]),
    .io_rxPtTestReqIntfIo_ptTestResults_bits_13        (vif.rxPtTestReq_ptTestResults_bits[13]),
    .io_rxPtTestReqIntfIo_ptTestResults_bits_14        (vif.rxPtTestReq_ptTestResults_bits[14]),
    .io_rxPtTestReqIntfIo_ptTestResults_bits_15        (vif.rxPtTestReq_ptTestResults_bits[15]),
    .io_rxPtTestReqIntfIo_start                        (vif.rxPtTestReq_start),
    .io_rxPtTestReqIntfIo_linkTrainingParameters_clockPhase    (),
    .io_rxPtTestReqIntfIo_linkTrainingParameters_dataPattern   (),
    .io_rxPtTestReqIntfIo_linkTrainingParameters_validPattern  (),
    .io_rxPtTestReqIntfIo_linkTrainingParameters_patternMode   (),
    .io_rxPtTestReqIntfIo_linkTrainingParameters_iterationCount(),
    .io_rxPtTestReqIntfIo_linkTrainingParameters_idleCount     (),
    .io_rxPtTestReqIntfIo_linkTrainingParameters_burstCount    (),
    .io_rxPtTestReqIntfIo_linkTrainingParameters_maxErrorThreshold(),
    .io_rxPtTestReqIntfIo_linkTrainingParameters_comparisonMode(),
    .io_rxPtTestReqIntfIo_patternType                          (),

    // RxEyeSweep Requester
    .io_rxEyeSweepReqIntfIo_done                        (vif.rxEyeSweepReq_done),
    .io_rxEyeSweepReqIntfIo_eyeSweepTestResults_valid   (vif.rxEyeSweepReq_eyeSweepTestResults_valid),
    .io_rxEyeSweepReqIntfIo_eyeSweepTestResults_bits_0  (vif.rxEyeSweepReq_eyeSweepTestResults_bits[0]),
    .io_rxEyeSweepReqIntfIo_eyeSweepTestResults_bits_1  (vif.rxEyeSweepReq_eyeSweepTestResults_bits[1]),
    .io_rxEyeSweepReqIntfIo_eyeSweepTestResults_bits_2  (vif.rxEyeSweepReq_eyeSweepTestResults_bits[2]),
    .io_rxEyeSweepReqIntfIo_eyeSweepTestResults_bits_3  (vif.rxEyeSweepReq_eyeSweepTestResults_bits[3]),
    .io_rxEyeSweepReqIntfIo_eyeSweepTestResults_bits_4  (vif.rxEyeSweepReq_eyeSweepTestResults_bits[4]),
    .io_rxEyeSweepReqIntfIo_eyeSweepTestResults_bits_5  (vif.rxEyeSweepReq_eyeSweepTestResults_bits[5]),
    .io_rxEyeSweepReqIntfIo_eyeSweepTestResults_bits_6  (vif.rxEyeSweepReq_eyeSweepTestResults_bits[6]),
    .io_rxEyeSweepReqIntfIo_eyeSweepTestResults_bits_7  (vif.rxEyeSweepReq_eyeSweepTestResults_bits[7]),
    .io_rxEyeSweepReqIntfIo_eyeSweepTestResults_bits_8  (vif.rxEyeSweepReq_eyeSweepTestResults_bits[8]),
    .io_rxEyeSweepReqIntfIo_eyeSweepTestResults_bits_9  (vif.rxEyeSweepReq_eyeSweepTestResults_bits[9]),
    .io_rxEyeSweepReqIntfIo_eyeSweepTestResults_bits_10 (vif.rxEyeSweepReq_eyeSweepTestResults_bits[10]),
    .io_rxEyeSweepReqIntfIo_eyeSweepTestResults_bits_11 (vif.rxEyeSweepReq_eyeSweepTestResults_bits[11]),
    .io_rxEyeSweepReqIntfIo_eyeSweepTestResults_bits_12 (vif.rxEyeSweepReq_eyeSweepTestResults_bits[12]),
    .io_rxEyeSweepReqIntfIo_eyeSweepTestResults_bits_13 (vif.rxEyeSweepReq_eyeSweepTestResults_bits[13]),
    .io_rxEyeSweepReqIntfIo_eyeSweepTestResults_bits_14 (vif.rxEyeSweepReq_eyeSweepTestResults_bits[14]),
    .io_rxEyeSweepReqIntfIo_eyeSweepTestResults_bits_15 (vif.rxEyeSweepReq_eyeSweepTestResults_bits[15]),
    .io_rxEyeSweepReqIntfIo_start                        (vif.rxEyeSweepReq_start),
    .io_rxEyeSweepReqIntfIo_linkTrainingParameters_clockPhase    (),
    .io_rxEyeSweepReqIntfIo_linkTrainingParameters_dataPattern   (),
    .io_rxEyeSweepReqIntfIo_linkTrainingParameters_validPattern  (),
    .io_rxEyeSweepReqIntfIo_linkTrainingParameters_patternMode   (),
    .io_rxEyeSweepReqIntfIo_linkTrainingParameters_iterationCount(),
    .io_rxEyeSweepReqIntfIo_linkTrainingParameters_idleCount     (),
    .io_rxEyeSweepReqIntfIo_linkTrainingParameters_burstCount    (),
    .io_rxEyeSweepReqIntfIo_linkTrainingParameters_maxErrorThreshold(),
    .io_rxEyeSweepReqIntfIo_linkTrainingParameters_comparisonMode(),
    .io_rxEyeSweepReqIntfIo_patternType                          (),

    // Responder stubs
    .io_txPtTestRespIntfIo_done      (vif.txPtTestResp_done),
    .io_txPtTestRespIntfIo_start     (vif.txPtTestResp_start),
    .io_txPtTestRespIntfIo_patternType(),
    .io_txEyeSweepRespIntfIo_done    (vif.txEyeSweepResp_done),
    .io_txEyeSweepRespIntfIo_start   (vif.txEyeSweepResp_start),
    .io_txEyeSweepRespIntfIo_patternType(),
    .io_rxPtTestRespIntfIo_done      (vif.rxPtTestResp_done),
    .io_rxPtTestRespIntfIo_start     (vif.rxPtTestResp_start),
    .io_rxPtTestRespIntfIo_patternType(),
    .io_rxEyeSweepRespIntfIo_done    (vif.rxEyeSweepResp_done),
    .io_rxEyeSweepRespIntfIo_start   (vif.rxEyeSweepResp_start),
    .io_rxEyeSweepRespIntfIo_patternType()
  );

  // Mirror mbLaneCtrl bus into interface for monitoring
  assign vif.mbLaneCtrl_txDataTriState = mbLane_txDataTriState;
  assign vif.mbLaneCtrl_txClkTriState  = mbLane_txClkTriState;
  assign vif.mbLaneCtrl_txValidTriState = mbLane_txValidTriState;
  assign vif.mbLaneCtrl_txTrackTriState = mbLane_txTrackTriState;
  assign vif.mbLaneCtrl_rxDataEn        = mbLane_rxDataEn;
  assign vif.mbLaneCtrl_rxClkEn         = mbLane_rxClkEn;
  assign vif.mbLaneCtrl_rxValidEn       = mbLane_rxValidEn;
  assign vif.mbLaneCtrl_rxTrackEn       = mbLane_rxTrackEn;

  initial begin
    uvm_config_db#(virtual mbtrain_if)::set(null, "*", "mbtrain_vif", vif);
    run_test();
  end

endmodule
