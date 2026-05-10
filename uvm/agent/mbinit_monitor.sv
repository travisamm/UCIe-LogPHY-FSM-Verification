`ifndef MBINIT_MONITOR_SV
`define MBINIT_MONITOR_SV

class mbinit_monitor extends uvm_monitor;
  `uvm_component_utils(mbinit_monitor)

  virtual mbinit_if vif;
  uvm_analysis_port #(mbinit_transaction) item_collected_port;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    item_collected_port = new("item_collected_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mbinit_if)::get(this, "", "mbinit_vif", vif))
      `uvm_fatal("NO_VIF", {"virtual interface must be set for: ", get_full_name(), ".vif"});
  endfunction

  task run_phase(uvm_phase phase);
    mbinit_transaction tx;
    logic [2:0]  prev_state;
    logic        prev_done;
    logic        prev_error;
    logic        prev_neg_valid;
    logic        prev_req_tx_valid;
    logic        prev_rsp_tx_valid;
    logic        prev_pw_req_valid;
    logic        prev_pr_req_valid;
    logic        prev_pttest_start;
    logic [15:0] prev_txDataTriState;
    logic        prev_txClkTriState;
    logic        prev_txValidTriState;
    logic        prev_txTrackTriState;
    logic [15:0] prev_rxDataEn;
    logic        prev_rxClkEn;
    logic        prev_rxValidEn;
    logic        prev_rxTrackEn;

    prev_state          = 3'hX;
    prev_done           = 0;
    prev_error          = 0;
    prev_neg_valid      = 0;
    prev_req_tx_valid   = 0;
    prev_rsp_tx_valid   = 0;
    prev_pw_req_valid   = 0;
    prev_pr_req_valid   = 0;
    prev_pttest_start   = 0;
    prev_txDataTriState = 16'hX;
    prev_txClkTriState  = 1'bX;
    prev_txValidTriState= 1'bX;
    prev_txTrackTriState= 1'bX;
    prev_rxDataEn       = 16'hX;
    prev_rxClkEn        = 1'bX;
    prev_rxValidEn      = 1'bX;
    prev_rxTrackEn      = 1'bX;

    forever begin
      @(posedge vif.clock);

      if ((vif.currentState              !== prev_state)          ||
          (vif.fsmCtrl_done             !== prev_done)            ||
          (vif.fsmCtrl_error            !== prev_error)           ||
          (vif.negotiatedPhySettings_valid !== prev_neg_valid)    ||
          (vif.requesterSbLaneIo_tx_valid !== prev_req_tx_valid)  ||
          (vif.responderSbLaneIo_tx_valid !== prev_rsp_tx_valid)  ||
          (vif.patternWriterIo_req_valid  !== prev_pw_req_valid)  ||
          (vif.patternReaderIo_req_valid  !== prev_pr_req_valid)  ||
          (vif.txPtTestReqIo_start        !== prev_pttest_start)  ||
          (vif.mbLaneCtrl_txDataTriState  !== prev_txDataTriState)||
          (vif.mbLaneCtrl_txClkTriState   !== prev_txClkTriState) ||
          (vif.mbLaneCtrl_txValidTriState !== prev_txValidTriState)||
          (vif.mbLaneCtrl_txTrackTriState !== prev_txTrackTriState)||
          (vif.mbLaneCtrl_rxDataEn        !== prev_rxDataEn)      ||
          (vif.mbLaneCtrl_rxClkEn         !== prev_rxClkEn)       ||
          (vif.mbLaneCtrl_rxValidEn       !== prev_rxValidEn)     ||
          (vif.mbLaneCtrl_rxTrackEn       !== prev_rxTrackEn)) begin

        tx = mbinit_transaction::type_id::create("tx");
        // Inherited observed fields (logphy_transaction)
        tx.fsm_done     = vif.fsmCtrl_done;
        tx.fsm_error    = vif.fsmCtrl_error;
        tx.tx_valid     = vif.requesterSbLaneIo_tx_valid;
        tx.tx_data      = vif.requesterSbLaneIo_tx_bits_data;
        tx.rsp_tx_valid = vif.responderSbLaneIo_tx_valid;
        tx.rsp_tx_data  = vif.responderSbLaneIo_tx_bits_data;
        // MBINIT state observed fields
        tx.currentState                = vif.currentState;
        tx.negotiatedPhySettings_valid = vif.negotiatedPhySettings_valid;
        tx.negotiated_maxDataRate      = vif.negotiatedPhySettings_maxDataRate;
        tx.negotiated_clockMode        = vif.negotiatedPhySettings_clockMode;
        tx.interoperableParamsNotFound = vif.interoperableParamsNotFound;
        tx.applyLaneReversal           = vif.applyLaneReversal;
        // Pattern IO observations
        tx.usingPatternWriter      = vif.usingPatternWriter;
        tx.usingPatternReader      = vif.usingPatternReader;
        tx.patternWriter_req_valid = vif.patternWriterIo_req_valid;
        tx.patternWriter_patternType = vif.patternWriterIo_req_bits_patternType;
        tx.patternReader_req_valid   = vif.patternReaderIo_req_valid;
        tx.patternReader_patternType = vif.patternReaderIo_req_bits_patternType;
        tx.txPtTest_start            = vif.txPtTestReqIo_start;
        // Lane control observations
        tx.mbLaneCtrl_txDataTriState  = vif.mbLaneCtrl_txDataTriState;
        tx.mbLaneCtrl_txClkTriState   = vif.mbLaneCtrl_txClkTriState;
        tx.mbLaneCtrl_txValidTriState = vif.mbLaneCtrl_txValidTriState;
        tx.mbLaneCtrl_txTrackTriState = vif.mbLaneCtrl_txTrackTriState;
        tx.mbLaneCtrl_rxDataEn        = vif.mbLaneCtrl_rxDataEn;
        tx.mbLaneCtrl_rxClkEn         = vif.mbLaneCtrl_rxClkEn;
        tx.mbLaneCtrl_rxValidEn       = vif.mbLaneCtrl_rxValidEn;
        tx.mbLaneCtrl_rxTrackEn       = vif.mbLaneCtrl_rxTrackEn;

        item_collected_port.write(tx);

        prev_state           = vif.currentState;
        prev_done            = vif.fsmCtrl_done;
        prev_error           = vif.fsmCtrl_error;
        prev_neg_valid       = vif.negotiatedPhySettings_valid;
        prev_req_tx_valid    = vif.requesterSbLaneIo_tx_valid;
        prev_rsp_tx_valid    = vif.responderSbLaneIo_tx_valid;
        prev_pw_req_valid    = vif.patternWriterIo_req_valid;
        prev_pr_req_valid    = vif.patternReaderIo_req_valid;
        prev_pttest_start    = vif.txPtTestReqIo_start;
        prev_txDataTriState  = vif.mbLaneCtrl_txDataTriState;
        prev_txClkTriState   = vif.mbLaneCtrl_txClkTriState;
        prev_txValidTriState = vif.mbLaneCtrl_txValidTriState;
        prev_txTrackTriState = vif.mbLaneCtrl_txTrackTriState;
        prev_rxDataEn        = vif.mbLaneCtrl_rxDataEn;
        prev_rxClkEn         = vif.mbLaneCtrl_rxClkEn;
        prev_rxValidEn       = vif.mbLaneCtrl_rxValidEn;
        prev_rxTrackEn       = vif.mbLaneCtrl_rxTrackEn;
      end
    end
  endtask

endclass
`endif
