`ifndef MBINIT_DRIVER_SV
`define MBINIT_DRIVER_SV

class mbinit_driver extends uvm_driver #(mbinit_transaction);
  `uvm_component_utils(mbinit_driver)

  virtual mbinit_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mbinit_if)::get(this, "", "mbinit_vif", vif))
      `uvm_fatal("NO_VIF", {"virtual interface must be set for: ", get_full_name(), ".vif"});
  endfunction

  task run_phase(uvm_phase phase);
    // Idle defaults
    vif.fsmCtrl_start                  = 0;
    vif.localPhySettings_valid         = 1;
    vif.localPhySettings_voltageSwing  = 5'h1F;
    vif.localPhySettings_maxDataRate   = 4'hF;
    vif.localPhySettings_clockMode     = 1;
    vif.localPhySettings_clockPhase    = 0;
    vif.localPhySettings_ucieSx8      = 0;
    vif.localPhySettings_sbFeatExt    = 0;
    vif.localPhySettings_txAdjRuntime = 0;
    vif.localPhySettings_moduleId     = 0;
    vif.mbInitCalDone                  = 0;
    vif.requesterSbLaneIo_rx_valid     = 0;
    vif.requesterSbLaneIo_rx_bits_data = 0;
    vif.requesterSbLaneIo_tx_ready     = 0;
    vif.responderSbLaneIo_rx_valid     = 0;
    vif.responderSbLaneIo_rx_bits_data = 0;
    vif.responderSbLaneIo_tx_ready     = 0;
    vif.patternWriterIo_req_ready      = 1;
    vif.patternWriterIo_resp_complete  = 0;
    vif.patternReaderIo_req_ready      = 1;
    vif.patternReaderIo_resp_valid     = 0;
    vif.patternReaderIo_resp_bits_perLaneStatusBits = 16'hFFFF;
    vif.patternReaderIo_resp_bits_aggregateStatus   = 1;
    vif.txPtTestReqIo_done                  = 0;
    vif.txPtTestReqIo_ptTestResults_valid   = 0;
    vif.txPtTestReqIo_ptTestResults_bits    = 16'hFFFF;
    vif.txPtTestRespIo_done                 = 0;

    wait(vif.reset == 0);

    fork
      // Main driver loop
      forever begin
        seq_item_port.get_next_item(req);
        drive_item(req);
        seq_item_port.item_done();
      end

      // Drive ready as a response to valid so the testbench does not consume a
      // DUT sideband exchange before the DUT has presented a message.
      forever begin
        @(posedge vif.clock);
        vif.requesterSbLaneIo_tx_ready <= vif.requesterSbLaneIo_tx_valid;
        vif.responderSbLaneIo_tx_ready <= vif.responderSbLaneIo_tx_valid;
      end

      // Auto-stub: Cal — pulse mbInitCalDone when DUT asserts mbInitCalStart
      forever begin
        @(posedge vif.clock iff vif.mbInitCalStart);
        repeat(3) @(posedge vif.clock);
        vif.mbInitCalDone = 1;
        @(posedge vif.clock);
        vif.mbInitCalDone = 0;
      end

      // Auto-stub: PatternWriter — pulse resp_complete after req_valid
      forever begin
        @(posedge vif.clock iff vif.patternWriterIo_req_valid);
        repeat(5) @(posedge vif.clock);
        vif.patternWriterIo_resp_complete = 1;
        @(posedge vif.clock);
        vif.patternWriterIo_resp_complete = 0;
      end

      // Auto-stub: PatternReader — drive resp when done flag asserted
      forever begin
        @(posedge vif.clock iff (vif.patternReaderIo_req_valid &&
                                  vif.patternReaderIo_req_bits_done));
        vif.patternReaderIo_resp_valid = 1;
        vif.patternReaderIo_resp_bits_perLaneStatusBits =
          req.patternReader_perLaneStatusBits;
        vif.patternReaderIo_resp_bits_aggregateStatus =
          req.patternReader_aggregateStatus;
        @(posedge vif.clock);
        vif.patternReaderIo_resp_valid = 0;
      end

      // Auto-stub: TxPtTest Requester done
      forever begin
        @(posedge vif.clock iff vif.txPtTestReqIo_start);
        repeat(3) @(posedge vif.clock);
        vif.txPtTestReqIo_done               = 1;
        vif.txPtTestReqIo_ptTestResults_valid = 1;
        vif.txPtTestReqIo_ptTestResults_bits  = 16'hFFFF;
        @(posedge vif.clock);
        vif.txPtTestReqIo_done               = 0;
        vif.txPtTestReqIo_ptTestResults_valid = 0;
      end

      // Auto-stub: TxPtTest Responder done
      forever begin
        @(posedge vif.clock iff vif.txPtTestRespIo_start);
        repeat(3) @(posedge vif.clock);
        vif.txPtTestRespIo_done = 1;
        @(posedge vif.clock);
        vif.txPtTestRespIo_done = 0;
      end
    join
  endtask

  task drive_item(mbinit_transaction req);
    if (req.delay > 0) begin
      vif.requesterSbLaneIo_rx_valid = 0;
      vif.responderSbLaneIo_rx_valid = 0;
      repeat(req.delay) @(posedge vif.clock);
    end

    // fsmCtrl_start is a level signal held high until fsmCtrl_done — only assert, never clear
    if (req.start_fsm) vif.fsmCtrl_start = 1;
    vif.localPhySettings_voltageSwing  = req.local_voltageSwing;
    vif.localPhySettings_maxDataRate   = req.local_maxDataRate;
    vif.localPhySettings_clockMode     = req.local_clockMode;
    vif.localPhySettings_clockPhase    = req.local_clockPhase;
    vif.localPhySettings_sbFeatExt    = req.local_sbFeatExt;
    vif.localPhySettings_txAdjRuntime = req.local_txAdjRuntime;
    vif.localPhySettings_moduleId     = req.local_moduleId;
    vif.requesterSbLaneIo_rx_valid     = req.rx_valid;
    vif.requesterSbLaneIo_rx_bits_data = req.rx_data;
    vif.responderSbLaneIo_rx_valid     = req.rsp_rx_valid;
    vif.responderSbLaneIo_rx_bits_data = req.rsp_rx_data;

    repeat(req.hold_cycles > 0 ? req.hold_cycles : 1) @(posedge vif.clock);

    vif.requesterSbLaneIo_rx_valid = 0;
    vif.responderSbLaneIo_rx_valid = 0;
  endtask

endclass
`endif
