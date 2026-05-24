`ifndef MBINIT_LEGACY_ADAPTER_SV
`define MBINIT_LEGACY_ADAPTER_SV

// ---------------------------------------------------------------------------
// mbinit_legacy_adapter  (Pass 3 legacy facade)
// ---------------------------------------------------------------------------
// Keeps the existing tests compiling/running unchanged. The env factory-
// overrides mbinit_driver with this class, so env.agent.driver is still a
// mbinit_driver (the rm02/rm07/rm05 tests' $cast + flag-set keep working) but
// the run loop no longer drives the monolithic vif. Instead, for each legacy
// mbinit_transaction pulled from env.agent.sequencer it:
//   * updates the shared service policy (cal/pattern-reader/point-test knobs),
//   * decomposes the item into requester-RX, responder-RX, and FSM-control
//     sub-items and runs them concurrently on the new split sequencers via
//     execute_item (same simultaneous timing as the old monolithic drive_item).
// The RM scenario flags (inherited from mbinit_driver, set by the tests in
// end_of_elaboration) are copied into the service policy at start_of_simulation
// so the point-test stub sees them before it runs.
//
// The autonomous service stubs (cal / pattern-writer / pattern-reader /
// point-test) drive their own split interfaces and read the shared policy.
//
// TODO(pass 8): once tests start on env.vseqr with virtual sequences, this
// adapter and the legacy sequencer/monitor can be retired.
// ---------------------------------------------------------------------------
class mbinit_legacy_adapter extends mbinit_driver;
  `uvm_component_utils(mbinit_legacy_adapter)

  // Wired by the env in connect_phase.
  mbinit_rx_sequencer   req_rx_seqr;
  mbinit_rx_sequencer   rsp_rx_seqr;
  mbinit_ctrl_sequencer ctrl_seqr;
  mbinit_service_cfg    svc_cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Inherit build_phase from mbinit_driver (fetches mbinit_vif, inits the RM
  // flags). We never drive vif here, so the fetched handle is just unused.

  // Copy the RM scenario flags (set by tests in end_of_elaboration) into the
  // shared service policy before the stubs run.
  function void start_of_simulation_phase(uvm_phase phase);
    super.start_of_simulation_phase(phase);
    if (svc_cfg != null) begin
      svc_cfg.rm02_mixed_pt_first              = rm02_mixed_pt_first;
      svc_cfg.rm07_first_repairmb_pt_all_fault = rm07_first_repairmb_pt_all_fault;
      svc_cfg.rm05_post_repair_pt_sequence     = rm05_post_repair_pt_sequence;
    end
  endfunction

  // Override the run loop: decompose, do NOT call super (no legacy vif drive).
  task run_phase(uvm_phase phase);
    if (req_rx_seqr == null || rsp_rx_seqr == null || ctrl_seqr == null)
      `uvm_fatal("MBINIT_ADAPTER", "split sequencer handles not wired by env")
    forever begin
      seq_item_port.get_next_item(req);
      decompose(req);
      seq_item_port.item_done();
    end
  endtask

  task decompose(mbinit_transaction tr);
    mbinit_rx_transaction   rxq, rxs;
    mbinit_ctrl_transaction ctl;

    // Per-item service knobs (sticky; read live by the stubs).
    if (svc_cfg != null) begin
      svc_cfg.cal_done_repeat_cycles   = tr.cal_done_repeat_cycles;
      svc_cfg.pattern_reader_per_lane  = tr.patternReader_perLaneStatusBits;
      svc_cfg.pattern_reader_aggregate = tr.patternReader_aggregateStatus;
      svc_cfg.pt_test_results          = tr.pt_test_results_bits;
    end

    // Requester RX
    rxq = mbinit_rx_transaction::type_id::create("rxq");
    rxq.rx_valid    = tr.rx_valid;
    rxq.rx_data     = tr.rx_data;
    rxq.delay       = tr.delay;
    rxq.hold_cycles = tr.hold_cycles;

    // Responder RX
    rxs = mbinit_rx_transaction::type_id::create("rxs");
    rxs.rx_valid    = tr.rsp_rx_valid;
    rxs.rx_data     = tr.rsp_rx_data;
    rxs.delay       = tr.delay;
    rxs.hold_cycles = tr.hold_cycles;

    // FSM control + local PHY settings
    ctl = mbinit_ctrl_transaction::type_id::create("ctl");
    ctl.start_fsm          = tr.start_fsm;
    ctl.local_voltageSwing = tr.local_voltageSwing;
    ctl.local_maxDataRate  = tr.local_maxDataRate;
    ctl.local_clockMode    = tr.local_clockMode;
    ctl.local_clockPhase   = tr.local_clockPhase;
    ctl.local_ucieSx8      = 1'b0;
    ctl.local_sbFeatExt    = tr.local_sbFeatExt;
    ctl.local_txAdjRuntime = tr.local_txAdjRuntime;
    ctl.local_moduleId     = tr.local_moduleId;
    ctl.delay              = tr.delay;
    ctl.hold_cycles        = tr.hold_cycles;

    // Run the three channels concurrently (matches the legacy simultaneous
    // drive of rx + rsp_rx + ctrl, held for hold_cycles).
    fork
      ctrl_seqr.execute_item(ctl);
      req_rx_seqr.execute_item(rxq);
      rsp_rx_seqr.execute_item(rxs);
    join
  endtask

endclass

`endif
