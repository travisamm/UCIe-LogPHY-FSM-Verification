`ifndef MBINIT_IF_SV
`define MBINIT_IF_SV

interface mbinit_if(input logic clock, input logic reset);
  // FSM control
  logic        fsmCtrl_start;
  logic        fsmCtrl_substateTransitioning;
  logic        fsmCtrl_error;
  logic        fsmCtrl_done;

  // Local PHY settings (driven by TB)
  logic        localPhySettings_valid;
  logic [4:0]  localPhySettings_voltageSwing;
  logic [3:0]  localPhySettings_maxDataRate;
  logic        localPhySettings_clockMode;
  logic        localPhySettings_clockPhase;
  logic        localPhySettings_ucieSx8;
  logic        localPhySettings_sbFeatExt;
  logic        localPhySettings_txAdjRuntime;
  logic [1:0]  localPhySettings_moduleId;

  // Negotiated PHY settings (observed from DUT)
  logic        negotiatedPhySettings_valid;
  logic [4:0]  negotiatedPhySettings_voltageSwing;
  logic [3:0]  negotiatedPhySettings_maxDataRate;
  logic        negotiatedPhySettings_clockMode;
  logic        negotiatedPhySettings_clockPhase;
  logic [1:0]  negotiatedPhySettings_moduleId;

  // State / error outputs
  logic [2:0]  currentState;
  logic        interoperableParamsNotFound;
  logic        usingPatternWriter;
  logic        usingPatternReader;
  logic        applyLaneReversal;
  logic [2:0]  localFunctionalLanes;
  logic        txWidthChanged;
  logic [2:0]  remoteFunctionalLanes;
  logic        rxWidthChanged;

  // Cal interface
  logic        mbInitCalDone;
  logic        mbInitCalStart;

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

  // PatternWriter stub (TB drives)
  logic        patternWriterIo_req_ready;
  logic        patternWriterIo_req_valid;
  logic [1:0]  patternWriterIo_req_bits_patternType;
  logic        patternWriterIo_resp_complete;

  // PatternReader stub (TB drives resp side; packed bus split in tb_top)
  logic        patternReaderIo_req_valid;
  logic [1:0]  patternReaderIo_req_bits_patternType;
  logic        patternReaderIo_req_bits_comparisonMode;
  logic [15:0] patternReaderIo_req_bits_errorThreshold;
  logic        patternReaderIo_req_bits_doConsecutiveCount;
  logic        patternReaderIo_req_ready;
  logic        patternReaderIo_req_bits_done;
  logic        patternReaderIo_req_bits_clear;
  logic        patternReaderIo_resp_valid;
  logic [15:0] patternReaderIo_resp_bits_perLaneStatusBits;
  logic        patternReaderIo_resp_bits_aggregateStatus;

  // TxPtTest Requester stub
  logic        txPtTestReqIo_done;
  logic        txPtTestReqIo_ptTestResults_valid;
  logic [15:0] txPtTestReqIo_ptTestResults_bits;
  logic        txPtTestReqIo_start;

  // TxPtTest Responder stub
  logic        txPtTestRespIo_done;
  logic        txPtTestRespIo_start;

endinterface
`endif
