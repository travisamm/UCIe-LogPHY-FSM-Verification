`timescale 1ns/1ps
/*
Run MBINIT:
make mbinit                                  # default: test_mbinit_sanity
make mbinit MBTEST=test_mbinit_sanity
make mbinit MBTEST=test_mbinit_param_mismatch
make mbinit MBTEST=test_mbinit_param_only
make mbinit_regress                          # runs all three above

Run MBTRAIN:
make mbtrain                                 # default: mbtrain_base_test
make mbtrain MBTRAINTEST=mbtrain_base_test
make mbtrain_regress                       # runs mbtrain_base_test and mbtrain_timeout_test
*/
module mbinit_tb_top;
  import uvm_pkg::*;
  import mbinit_env_pkg::*;
  import mbinit_seq_pkg::*;
  import mbinit_test_pkg::*;

  logic clock;
  logic reset;

  initial begin clock = 0; forever #5 clock = ~clock; end
  initial begin reset = 1; #20 reset = 0; end

  mbinit_if vif(clock, reset);

  // Dummy wires for DUT mbLaneCtrlIo outputs (not monitored by TB)
  wire [15:0] mbLane_rxDataEn;
  wire        mbLane_rxClkEn, mbLane_rxValidEn, mbLane_rxTrackEn;

  MBInitSM dut (
    .clock  (clock),
    .reset  (reset),

    // FSM control
    .io_fsmCtrl_start                (vif.fsmCtrl_start),
    .io_fsmCtrl_substateTransitioning(vif.fsmCtrl_substateTransitioning),
    .io_fsmCtrl_error                (vif.fsmCtrl_error),
    .io_fsmCtrl_done                 (vif.fsmCtrl_done),

    // Local PHY settings
    .io_localPhySettings_valid                 (vif.localPhySettings_valid),
    .io_localPhySettings_bits_voltageSwing     (vif.localPhySettings_voltageSwing),
    .io_localPhySettings_bits_maxDataRate      (vif.localPhySettings_maxDataRate),
    .io_localPhySettings_bits_clockMode        (vif.localPhySettings_clockMode),
    .io_localPhySettings_bits_clockPhase       (vif.localPhySettings_clockPhase),
    .io_localPhySettings_bits_ucieSx8         (vif.localPhySettings_ucieSx8),
    .io_localPhySettings_bits_sbFeatExt       (vif.localPhySettings_sbFeatExt),
    .io_localPhySettings_bits_txAdjRuntime    (vif.localPhySettings_txAdjRuntime),
    .io_localPhySettings_bits_moduleId         (vif.localPhySettings_moduleId),

    // Negotiated PHY settings (DUT outputs → interface for observation)
    .io_negotiatedPhySettings_valid                (vif.negotiatedPhySettings_valid),
    .io_negotiatedPhySettings_bits_voltageSwing    (vif.negotiatedPhySettings_voltageSwing),
    .io_negotiatedPhySettings_bits_maxDataRate     (vif.negotiatedPhySettings_maxDataRate),
    .io_negotiatedPhySettings_bits_clockMode       (vif.negotiatedPhySettings_clockMode),
    .io_negotiatedPhySettings_bits_clockPhase      (vif.negotiatedPhySettings_clockPhase),
    .io_negotiatedPhySettings_bits_ucieSx8        (),
    .io_negotiatedPhySettings_bits_sbFeatExt      (),
    .io_negotiatedPhySettings_bits_txAdjRuntime   (),
    .io_negotiatedPhySettings_bits_moduleId        (vif.negotiatedPhySettings_moduleId),

    // State outputs
    .io_currentState                (vif.currentState),
    .io_interoperableParamsNotFound (vif.interoperableParamsNotFound),
    .io_usingPatternWriter          (vif.usingPatternWriter),
    .io_usingPatternReader          (vif.usingPatternReader),
    .io_applyLaneReversal           (vif.applyLaneReversal),
    .io_localFunctionalLanes        (vif.localFunctionalLanes),
    .io_txWidthChanged              (vif.txWidthChanged),
    .io_remoteFunctionalLanes       (vif.remoteFunctionalLanes),
    .io_rxWidthChanged              (vif.rxWidthChanged),

    // MbLaneCtrl (outputs tied to dummy wires)
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
    .io_mbLaneCtrlIo_rxClkEn    (mbLane_rxClkEn),
    .io_mbLaneCtrlIo_rxValidEn  (mbLane_rxValidEn),
    .io_mbLaneCtrlIo_rxTrackEn  (mbLane_rxTrackEn),

    // Cal
    .io_mbInitCalDone  (vif.mbInitCalDone),
    .io_mbInitCalStart (vif.mbInitCalStart),

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

    // PatternWriter
    .io_patternWriterIo_req_ready            (vif.patternWriterIo_req_ready),
    .io_patternWriterIo_req_valid            (vif.patternWriterIo_req_valid),
    .io_patternWriterIo_req_bits_patternType (vif.patternWriterIo_req_bits_patternType),
    .io_patternWriterIo_resp_complete        (vif.patternWriterIo_resp_complete),

    // PatternReader
    .io_patternReaderIo_req_ready                   (vif.patternReaderIo_req_ready),
    .io_patternReaderIo_req_valid                   (vif.patternReaderIo_req_valid),
    .io_patternReaderIo_req_bits_patternType        (vif.patternReaderIo_req_bits_patternType),
    .io_patternReaderIo_req_bits_comparisonMode     (vif.patternReaderIo_req_bits_comparisonMode),
    .io_patternReaderIo_req_bits_errorThreshold     (vif.patternReaderIo_req_bits_errorThreshold),
    .io_patternReaderIo_req_bits_doConsecutiveCount (vif.patternReaderIo_req_bits_doConsecutiveCount),
    .io_patternReaderIo_req_bits_done               (vif.patternReaderIo_req_bits_done),
    .io_patternReaderIo_req_bits_clear              (vif.patternReaderIo_req_bits_clear),
    .io_patternReaderIo_resp_valid                  (vif.patternReaderIo_resp_valid),
    // 16-bit packed bus split to individual DUT inputs
    .io_patternReaderIo_resp_bits_perLaneStatusBits_0  (vif.patternReaderIo_resp_bits_perLaneStatusBits[0]),
    .io_patternReaderIo_resp_bits_perLaneStatusBits_1  (vif.patternReaderIo_resp_bits_perLaneStatusBits[1]),
    .io_patternReaderIo_resp_bits_perLaneStatusBits_2  (vif.patternReaderIo_resp_bits_perLaneStatusBits[2]),
    .io_patternReaderIo_resp_bits_perLaneStatusBits_3  (vif.patternReaderIo_resp_bits_perLaneStatusBits[3]),
    .io_patternReaderIo_resp_bits_perLaneStatusBits_4  (vif.patternReaderIo_resp_bits_perLaneStatusBits[4]),
    .io_patternReaderIo_resp_bits_perLaneStatusBits_5  (vif.patternReaderIo_resp_bits_perLaneStatusBits[5]),
    .io_patternReaderIo_resp_bits_perLaneStatusBits_6  (vif.patternReaderIo_resp_bits_perLaneStatusBits[6]),
    .io_patternReaderIo_resp_bits_perLaneStatusBits_7  (vif.patternReaderIo_resp_bits_perLaneStatusBits[7]),
    .io_patternReaderIo_resp_bits_perLaneStatusBits_8  (vif.patternReaderIo_resp_bits_perLaneStatusBits[8]),
    .io_patternReaderIo_resp_bits_perLaneStatusBits_9  (vif.patternReaderIo_resp_bits_perLaneStatusBits[9]),
    .io_patternReaderIo_resp_bits_perLaneStatusBits_10 (vif.patternReaderIo_resp_bits_perLaneStatusBits[10]),
    .io_patternReaderIo_resp_bits_perLaneStatusBits_11 (vif.patternReaderIo_resp_bits_perLaneStatusBits[11]),
    .io_patternReaderIo_resp_bits_perLaneStatusBits_12 (vif.patternReaderIo_resp_bits_perLaneStatusBits[12]),
    .io_patternReaderIo_resp_bits_perLaneStatusBits_13 (vif.patternReaderIo_resp_bits_perLaneStatusBits[13]),
    .io_patternReaderIo_resp_bits_perLaneStatusBits_14 (vif.patternReaderIo_resp_bits_perLaneStatusBits[14]),
    .io_patternReaderIo_resp_bits_perLaneStatusBits_15 (vif.patternReaderIo_resp_bits_perLaneStatusBits[15]),
    .io_patternReaderIo_resp_bits_aggregateStatus      (vif.patternReaderIo_resp_bits_aggregateStatus),

    // TxPtTest Requester
    .io_txPtTestReqInterfaceIo_done                    (vif.txPtTestReqIo_done),
    .io_txPtTestReqInterfaceIo_ptTestResults_valid      (vif.txPtTestReqIo_ptTestResults_valid),
    .io_txPtTestReqInterfaceIo_ptTestResults_bits_0    (vif.txPtTestReqIo_ptTestResults_bits[0]),
    .io_txPtTestReqInterfaceIo_ptTestResults_bits_1    (vif.txPtTestReqIo_ptTestResults_bits[1]),
    .io_txPtTestReqInterfaceIo_ptTestResults_bits_2    (vif.txPtTestReqIo_ptTestResults_bits[2]),
    .io_txPtTestReqInterfaceIo_ptTestResults_bits_3    (vif.txPtTestReqIo_ptTestResults_bits[3]),
    .io_txPtTestReqInterfaceIo_ptTestResults_bits_4    (vif.txPtTestReqIo_ptTestResults_bits[4]),
    .io_txPtTestReqInterfaceIo_ptTestResults_bits_5    (vif.txPtTestReqIo_ptTestResults_bits[5]),
    .io_txPtTestReqInterfaceIo_ptTestResults_bits_6    (vif.txPtTestReqIo_ptTestResults_bits[6]),
    .io_txPtTestReqInterfaceIo_ptTestResults_bits_7    (vif.txPtTestReqIo_ptTestResults_bits[7]),
    .io_txPtTestReqInterfaceIo_ptTestResults_bits_8    (vif.txPtTestReqIo_ptTestResults_bits[8]),
    .io_txPtTestReqInterfaceIo_ptTestResults_bits_9    (vif.txPtTestReqIo_ptTestResults_bits[9]),
    .io_txPtTestReqInterfaceIo_ptTestResults_bits_10   (vif.txPtTestReqIo_ptTestResults_bits[10]),
    .io_txPtTestReqInterfaceIo_ptTestResults_bits_11   (vif.txPtTestReqIo_ptTestResults_bits[11]),
    .io_txPtTestReqInterfaceIo_ptTestResults_bits_12   (vif.txPtTestReqIo_ptTestResults_bits[12]),
    .io_txPtTestReqInterfaceIo_ptTestResults_bits_13   (vif.txPtTestReqIo_ptTestResults_bits[13]),
    .io_txPtTestReqInterfaceIo_ptTestResults_bits_14   (vif.txPtTestReqIo_ptTestResults_bits[14]),
    .io_txPtTestReqInterfaceIo_ptTestResults_bits_15   (vif.txPtTestReqIo_ptTestResults_bits[15]),
    .io_txPtTestReqInterfaceIo_start                   (vif.txPtTestReqIo_start),
    .io_txPtTestReqInterfaceIo_linkTrainingParameters_clockPhase    (),
    .io_txPtTestReqInterfaceIo_linkTrainingParameters_dataPattern   (),
    .io_txPtTestReqInterfaceIo_linkTrainingParameters_validPattern  (),
    .io_txPtTestReqInterfaceIo_linkTrainingParameters_patternMode   (),
    .io_txPtTestReqInterfaceIo_linkTrainingParameters_iterationCount(),
    .io_txPtTestReqInterfaceIo_linkTrainingParameters_idleCount     (),
    .io_txPtTestReqInterfaceIo_linkTrainingParameters_burstCount    (),
    .io_txPtTestReqInterfaceIo_linkTrainingParameters_maxErrorThreshold(),
    .io_txPtTestReqInterfaceIo_linkTrainingParameters_comparisonMode(),
    .io_txPtTestReqInterfaceIo_patternType                          (),

    // TxPtTest Responder
    .io_txPtTestRespInterfaceIo_done       (vif.txPtTestRespIo_done),
    .io_txPtTestRespInterfaceIo_start      (vif.txPtTestRespIo_start),
    .io_txPtTestRespInterfaceIo_patternType()
  );

  initial begin
    uvm_config_db#(virtual mbinit_if)::set(null, "*", "mbinit_vif", vif);
    run_test();
  end

endmodule
