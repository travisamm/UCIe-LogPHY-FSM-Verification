`ifndef MBINIT_DRIVER_SV
`define MBINIT_DRIVER_SV

class mbinit_driver extends uvm_driver #(mbinit_transaction);
  `uvm_component_utils(mbinit_driver)

  virtual mbinit_if vif;
  logic prev_mb_init_cal_start;
  logic prev_pattern_reader_req_done;
  logic prev_tx_pt_start;
  // Pulses mbInitCalDone this many cycles after each rising edge of mbInitCalStart
  int unsigned cal_done_repeat_cycles = 3;
  // Last seq item fields for patternReader response (sticky across idle cycles)
  logic [15:0] sticky_pr_per_lane;
  logic        sticky_pr_aggregate;
  // Last seq item: Tx point test per-lane result bits (sticky)
  logic [15:0] sticky_pt_results;
  // RM-02: first Tx point-test result beat in REPAIRMB uses heterogeneous per-lane bits (TB proxy)
  bit          rm02_mixed_pt_first;
  // RM-07: first REPAIRMB Tx point-test returns all-lane faults → allLanesFailed → fsmCtrl_error
  bit          rm07_first_repairmb_pt_all_fault;
  // RM-05: first PT upper-half faults only (width degrade), second PT all faults → error (mutually exclusive with RM-02/07 in tests)
  bit          rm05_post_repair_pt_sequence;
  int unsigned rm02_repairmb_pt_idx;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mbinit_if)::get(this, "", "mbinit_vif", vif))
      `uvm_fatal("NO_VIF", {"virtual interface must be set for: ", get_full_name(), ".vif"});
    sticky_pr_per_lane   = 16'hFFFF;
    sticky_pr_aggregate  = 1'b1;
    sticky_pt_results    = 16'h0000;
    rm02_mixed_pt_first           = 1'b0;
    rm07_first_repairmb_pt_all_fault = 1'b0;
    rm05_post_repair_pt_sequence  = 1'b0;
    rm02_repairmb_pt_idx          = 0;
  endfunction

  task run_phase(uvm_phase phase);
    prev_mb_init_cal_start = 1'b0;
    prev_pattern_reader_req_done = 1'b0;
    prev_tx_pt_start = 1'b0;

    // Idle defaults
    vif.fsmCtrl_start                  = 0;
    vif.localPhySettings_valid         = 1;
    vif.localPhySettings_voltageSwing  = 5'h1F;
    vif.localPhySettings_maxDataRate   = 4'hF;
    vif.localPhySettings_clockMode     = 1;
    vif.localPhySettings_clockPhase    = 0;
    vif.localPhySettings_ucieSx8       = 0;
    vif.localPhySettings_sbFeatExt     = 0;
    vif.localPhySettings_txAdjRuntime  = 0;
    vif.localPhySettings_moduleId      = 0;
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
    // All 1s ⇒ faultInLower/Upper both true in full-width mode ⇒ allLanesFailed → REPAIRMB error
    vif.txPtTestReqIo_ptTestResults_bits    = 16'h0000;
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

      // Auto-stub: Cal — pulse mbInitCalDone once per rising edge of mbInitCalStart
      // (mbInitCalStart is level-high for all of sCAL; avoid re-trigger every cycle.)
      forever begin
        @(posedge vif.clock);
        if (vif.mbInitCalStart && !prev_mb_init_cal_start) begin
          repeat (cal_done_repeat_cycles) @(posedge vif.clock);
          vif.mbInitCalDone = 1;
          @(posedge vif.clock);
          vif.mbInitCalDone = 0;
        end
        prev_mb_init_cal_start = vif.mbInitCalStart;
      end

      // Auto-stub: PatternWriter — pulse resp_complete after req_valid
      forever begin
        @(posedge vif.clock iff vif.patternWriterIo_req_valid);
        repeat (5) @(posedge vif.clock);
        vif.patternWriterIo_resp_complete = 1;
        @(posedge vif.clock);
        vif.patternWriterIo_resp_complete = 0;
      end

      // Auto-stub: PatternReader — pulse resp on rising edge of req_bits_done.
      // MBInitSM responder REPAIRCLK/REPAIRVAL/REPAIRMB holds req.valid only in
      // substate s0; s1 drives done := msgReceived with req.valid false, so the
      // handshake must not require req_valid and done in the same cycle.
      forever begin
        @(posedge vif.clock);
        if (vif.patternReaderIo_req_bits_done && !prev_pattern_reader_req_done) begin
          vif.patternReaderIo_resp_valid = 1;
          vif.patternReaderIo_resp_bits_perLaneStatusBits = sticky_pr_per_lane;
          vif.patternReaderIo_resp_bits_aggregateStatus   = sticky_pr_aggregate;
          @(posedge vif.clock);
          vif.patternReaderIo_resp_valid = 0;
        end
        prev_pattern_reader_req_done = vif.patternReaderIo_req_bits_done;
      end

      // Auto-stub: TxPtTest Requester done
      forever begin
        @(posedge vif.clock);
        if (vif.currentState != 3'h5)
          rm02_repairmb_pt_idx = 0;
        if (vif.txPtTestReqIo_start && !prev_tx_pt_start) begin
          repeat (3) @(posedge vif.clock);
          begin
            logic [15:0] ptb;
            #0;
            if (vif.currentState == 3'h5) begin
              if (rm07_first_repairmb_pt_all_fault && rm02_repairmb_pt_idx == 0)
                ptb = 16'hFFFF; // faults on all lanes → allLanesFailed → REPAIRMB error path
              else if (rm05_post_repair_pt_sequence) begin
                if (rm02_repairmb_pt_idx == 0)
                  ptb = 16'hFF00; // upper half only → width degrade, loop PT (RM-05)
                else
                  ptb = 16'hFFFF; // after repair attempt, faults persist → error
              end
              else if (rm02_mixed_pt_first && rm02_repairmb_pt_idx == 0)
                ptb = 16'h0FF0; // mixed pass(1)/fail(0) across lanes for RM-02 witness
              else
                ptb = sticky_pt_results;
            end
            else
              ptb = sticky_pt_results;
            vif.txPtTestReqIo_done               = 1;
            vif.txPtTestReqIo_ptTestResults_valid = 1;
            vif.txPtTestReqIo_ptTestResults_bits  = ptb;
            @(posedge vif.clock);
            vif.txPtTestReqIo_done               = 0;
            vif.txPtTestReqIo_ptTestResults_valid = 0;
            if (vif.currentState == 3'h5)
              rm02_repairmb_pt_idx++;
          end
        end
        prev_tx_pt_start = vif.txPtTestReqIo_start;
      end

      // Auto-stub: TxPtTest Responder done
      forever begin
        @(posedge vif.clock iff vif.txPtTestRespIo_start);
        repeat (3) @(posedge vif.clock);
        vif.txPtTestRespIo_done = 1;
        @(posedge vif.clock);
        vif.txPtTestRespIo_done = 0;
      end
    join
  endtask

  task drive_item(mbinit_transaction req);
    cal_done_repeat_cycles = req.cal_done_repeat_cycles;
    sticky_pr_per_lane  = req.patternReader_perLaneStatusBits;
    sticky_pr_aggregate = req.patternReader_aggregateStatus;
    sticky_pt_results     = req.pt_test_results_bits;
    if (req.delay > 0) begin
      vif.requesterSbLaneIo_rx_valid = 0;
      vif.responderSbLaneIo_rx_valid = 0;
      repeat (req.delay) @(posedge vif.clock);
    end

    // fsmCtrl_start is a level signal held high until fsmCtrl_done — only assert, never clear
    if (req.start_fsm) vif.fsmCtrl_start = 1;
    vif.localPhySettings_voltageSwing  = req.local_voltageSwing;
    vif.localPhySettings_maxDataRate   = req.local_maxDataRate;
    vif.localPhySettings_clockMode     = req.local_clockMode;
    vif.localPhySettings_clockPhase    = req.local_clockPhase;
    vif.localPhySettings_sbFeatExt     = req.local_sbFeatExt;
    vif.localPhySettings_txAdjRuntime  = req.local_txAdjRuntime;
    vif.localPhySettings_moduleId      = req.local_moduleId;
    vif.requesterSbLaneIo_rx_valid     = req.rx_valid;
    vif.requesterSbLaneIo_rx_bits_data = req.rx_data;
    vif.responderSbLaneIo_rx_valid     = req.rsp_rx_valid;
    vif.responderSbLaneIo_rx_bits_data = req.rsp_rx_data;

    repeat (req.hold_cycles > 0 ? req.hold_cycles : 1) @(posedge vif.clock);

    vif.requesterSbLaneIo_rx_valid = 0;
    vif.responderSbLaneIo_rx_valid = 0;
  endtask

endclass
`endif
