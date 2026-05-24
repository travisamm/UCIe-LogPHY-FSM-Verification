`ifndef SBINIT_TESTS_SV
`define SBINIT_TESTS_SV

// ---------------------------------------------------------------------------
// SBINIT tests
// ---------------------------------------------------------------------------
//   make sbinit                                          # test_sbinit_sanity
//   make sbinit SBTEST=test_sbinit_timeout               # SBINIT timeout
//   make sbinit SBTEST=test_sbinit_partner_not_ready     # partner delays OoR
//   make sbinit SBTEST=test_sbinit_early_req             # premature done req
//   make sbinit SBTEST=test_sbinit_multiple_reqs         # collapse done reqs
//   make sbinit SBTEST=test_sbinit_req_backpressure      # requester back-pressure
//   make sbinit SBTEST=test_sbinit_rsp_backpressure      # responder back-pressure
//   make sbinit_regress                                  # all of the above
//
// Each test sets sbinit_env_cfg expectations relevant to the scenario, then
// starts the matching virtual sequence on env.vseqr. Completion is driven by
// the protocol (vseq waits on fsmCtrl_done) plus a small drain interval.
// ---------------------------------------------------------------------------

// Tiny tail so monitors flush any final events into the scoreboard before
// check_phase runs.
`define SBINIT_DRAIN_NS 500

// ---------------------------------------------------------------------------
// test_sbinit_sanity
//   Confirms the happy-path SBINIT handshake:
//     - Clock-pattern transmission and stop-after-detection
//     - Partner clock-pattern sampling
//     - Sideband mode transition to functional
//     - Done request/response handshake completes
//     - fsmCtrl_done asserts cleanly
// ---------------------------------------------------------------------------
class test_sbinit_sanity extends sbinit_base_test;
  `uvm_component_utils(test_sbinit_sanity)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Defaults already match the requirements this test covers.
  task run_phase(uvm_phase phase);
    sbinit_sanity_vseq vseq;
    phase.raise_objection(this, "test_sbinit_sanity");

    `uvm_info("TEST",
              "Starting test_sbinit_sanity: drive partner clock pattern, Out of Reset, then done req/resp",
              UVM_LOW)

    vseq = sbinit_sanity_vseq::type_id::create("vseq");
    vseq.start(env.vseqr);

    #(`SBINIT_DRAIN_NS);
    `uvm_info("TEST", "test_sbinit_sanity stimulus complete; entering check_phase", UVM_LOW)
    phase.drop_objection(this, "test_sbinit_sanity");
  endtask
endclass

// ---------------------------------------------------------------------------
// test_sbinit_timeout
//   Kicks the FSM without driving any partner activity. fsmCtrl_done must
//   NOT assert. (fsmCtrl_error is hardcoded 0 in this RTL, so we cannot
//   directly observe TRAINERROR; we only validate the absence of done.)
// ---------------------------------------------------------------------------
class test_sbinit_timeout extends sbinit_base_test;
  `uvm_component_utils(test_sbinit_timeout)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // No partner stimulus → none of these can be witnessed.
    cfg.expect_sb01_clock_pattern   = 0;
    cfg.expect_sb02_rx_sampling     = 0;
    cfg.expect_sb03_stop_on_detect  = 0;
    cfg.expect_sb05_mode_transition = 0;
    cfg.expect_sb06_out_of_reset    = 0;
    cfg.expect_sb07_done_handshake  = 0;
    cfg.expect_fsm_done             = 0;
  endfunction

  task run_phase(uvm_phase phase);
    sbinit_timeout_vseq vseq;
    phase.raise_objection(this, "test_sbinit_timeout");

    `uvm_info("TEST",
              "Starting test_sbinit_timeout: kick FSM with no partner stimulus and confirm fsmCtrl_done stays low",
              UVM_LOW)

    vseq = sbinit_timeout_vseq::type_id::create("vseq");
    vseq.start(env.vseqr);

    #(`SBINIT_DRAIN_NS);
    `uvm_info("TEST", "test_sbinit_timeout stimulus complete; entering check_phase", UVM_LOW)
    phase.drop_objection(this, "test_sbinit_timeout");
  endtask
endclass

// ---------------------------------------------------------------------------
// test_sbinit_partner_not_ready
//   Stretches the gap between partner clock pattern and partner {Out of
//   Reset}. Verifies the DUT keeps emitting its own Out of Reset across that
//   gap so partner detection works whenever it eventually arrives.
// ---------------------------------------------------------------------------
class test_sbinit_partner_not_ready extends sbinit_base_test;
  `uvm_component_utils(test_sbinit_partner_not_ready)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    sbinit_partner_not_ready_vseq vseq;
    phase.raise_objection(this, "test_sbinit_partner_not_ready");

    `uvm_info("TEST",
              "Starting test_sbinit_partner_not_ready: delay partner Out-of-Reset and verify DUT keeps emitting its own",
              UVM_LOW)

    vseq = sbinit_partner_not_ready_vseq::type_id::create("vseq");
    vseq.start(env.vseqr);

    #(`SBINIT_DRAIN_NS);
    `uvm_info("TEST", "test_sbinit_partner_not_ready stimulus complete; entering check_phase", UVM_LOW)
    phase.drop_objection(this, "test_sbinit_partner_not_ready");
  endtask
endclass

// ---------------------------------------------------------------------------
// test_sbinit_early_req
//   Sends a partner {done req} before the partner has acknowledged the DUT's
//   Out of Reset. DUT must ignore the early request and only complete once
//   the proper sequence is driven afterwards.
// ---------------------------------------------------------------------------
class test_sbinit_early_req extends sbinit_base_test;
  `uvm_component_utils(test_sbinit_early_req)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg.expect_sb08_ignore_early = 1;
  endfunction

  task run_phase(uvm_phase phase);
    sbinit_early_req_vseq vseq;
    phase.raise_objection(this, "test_sbinit_early_req");

    `uvm_info("TEST",
              "Starting test_sbinit_early_req: send partner done req before Out-of-Reset and verify DUT ignores it",
              UVM_LOW)

    vseq = sbinit_early_req_vseq::type_id::create("vseq");
    vseq.start(env.vseqr);

    #(`SBINIT_DRAIN_NS);
    `uvm_info("TEST", "test_sbinit_early_req stimulus complete; entering check_phase", UVM_LOW)
    phase.drop_objection(this, "test_sbinit_early_req");
  endtask
endclass

// ---------------------------------------------------------------------------
// test_sbinit_multiple_reqs
//   Holds responder tx_ready low while the partner sends multiple {done req}
//   bursts, then releases ready. The DUT must collapse those into a single
//   {done resp} and complete.
// ---------------------------------------------------------------------------
class test_sbinit_multiple_reqs extends sbinit_base_test;
  `uvm_component_utils(test_sbinit_multiple_reqs)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg.expect_sb09_collapse_reqs = 1;
  endfunction

  task run_phase(uvm_phase phase);
    sbinit_collapse_reqs_vseq vseq;
    phase.raise_objection(this, "test_sbinit_multiple_reqs");

    `uvm_info("TEST",
              "Starting test_sbinit_multiple_reqs: hold responder ready low across multiple done reqs and verify single done resp",
              UVM_LOW)

    vseq = sbinit_collapse_reqs_vseq::type_id::create("vseq");
    vseq.start(env.vseqr);

    #(`SBINIT_DRAIN_NS);
    `uvm_info("TEST", "test_sbinit_multiple_reqs stimulus complete; entering check_phase", UVM_LOW)
    phase.drop_objection(this, "test_sbinit_multiple_reqs");
  endtask
endclass

// ---------------------------------------------------------------------------
// test_sbinit_req_backpressure
//   Pins down a ready/valid stability requirement that the other tests do
//   not exercise: while in the sOUT_OF_RESET state the DUT must hold its
//   {SBINIT Out of Reset} payload on requester tx_data the entire time
//   tx_valid is high, regardless of tx_ready.
//
//   This test is EXPECTED TO FAIL on the current RTL (SBInit.scala
//   lines 128-132 assign tx.bits.data inside `when(tx.ready)`). The bound
//   payload-stability SVA (sbinit_payload_stability_sva on the requester TX
//   stream) fires: tx_data changes to 0 while tx_valid is held and tx_ready is
//   low. The scoreboard's semantic "offered-under-back-pressure was accepted"
//   liveness row still PASSES (the handshake completes; only the payload is
//   corrupt), so the failure has exactly one meaningful owner: the SVA.
//
//   It is intentionally a separate test so test_sbinit_multiple_reqs (and
//   every other SBINIT test) can pass independently. Once the Scala fix
//   lands this test should turn green automatically.
// ---------------------------------------------------------------------------
class test_sbinit_req_backpressure extends sbinit_base_test;
  `uvm_component_utils(test_sbinit_req_backpressure)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Opt into the requester back-pressure checks: enables the payload-stability
    // SVA on the requester TX stream and the scoreboard liveness row. Gated so
    // tests that don't back-pressure the requester are unaffected.
    cfg.expect_req_tx_data_stable = 1;
  endfunction

  task run_phase(uvm_phase phase);
    sbinit_req_backpressure_vseq vseq;
    phase.raise_objection(this, "test_sbinit_req_backpressure");

    `uvm_info("TEST",
              "Starting test_sbinit_req_backpressure: hold requester tx_ready low during Out-of-Reset and verify tx_data stays at the OoR payload",
              UVM_LOW)

    vseq = sbinit_req_backpressure_vseq::type_id::create("vseq");
    vseq.start(env.vseqr);

    #(`SBINIT_DRAIN_NS);
    `uvm_info("TEST", "test_sbinit_req_backpressure stimulus complete; entering check_phase", UVM_LOW)
    phase.drop_objection(this, "test_sbinit_req_backpressure");
  endtask
endclass

// ---------------------------------------------------------------------------
// test_sbinit_rsp_backpressure
//   Responder-side analog of test_sbinit_req_backpressure. Drives the FSM to
//   the point where the responder has accepted a {done req} and wants to send
//   {done resp}, while holding the responder tx_ready LOW. With a correct DUT
//   the responder holds the {done resp} payload on tx_data the whole time
//   tx_valid is high; with the current RTL (SBInit.scala lines 183-187 assign
//   tx.bits.data inside `when(tx.ready)`) it drives tx_valid=1 with tx_data=0.
//
//   This test is EXPECTED TO FAIL on the current RTL: the bound payload-
//   stability SVA on the responder TX stream fires. It is a separate test (and
//   the check is opt-in via cfg) so that test_sbinit_multiple_reqs — which also
//   back-pressures the responder, but to verify done-req collapse rather than
//   data stability — keeps passing (its offered-under-back-pressure UNKNOWN
//   beats are not hard failures). The scoreboard's responder liveness row still
//   PASSES, so the SVA is the single failure owner. Turns green automatically
//   once the Scala fix lands.
// ---------------------------------------------------------------------------
class test_sbinit_rsp_backpressure extends sbinit_base_test;
  `uvm_component_utils(test_sbinit_rsp_backpressure)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Opt into the responder back-pressure checks (payload-stability SVA on the
    // responder TX stream + scoreboard liveness row).
    cfg.expect_rsp_tx_data_stable = 1;
  endfunction

  task run_phase(uvm_phase phase);
    sbinit_rsp_backpressure_vseq vseq;
    phase.raise_objection(this, "test_sbinit_rsp_backpressure");

    `uvm_info("TEST",
              "Starting test_sbinit_rsp_backpressure: hold responder tx_ready low while it owes a done resp and verify tx_data stays at the done-resp payload",
              UVM_LOW)

    vseq = sbinit_rsp_backpressure_vseq::type_id::create("vseq");
    vseq.start(env.vseqr);

    #(`SBINIT_DRAIN_NS);
    `uvm_info("TEST", "test_sbinit_rsp_backpressure stimulus complete; entering check_phase", UVM_LOW)
    phase.drop_objection(this, "test_sbinit_rsp_backpressure");
  endtask
endclass

// ---------------------------------------------------------------------------
// test_sbinit_reset
//   Mid-sim reset recovery. Injects a reset while a requester rx item is in
//   flight, then runs a clean full SBINIT to completion. Verifies the env is
//   reset-robust: drivers complete the aborted item (no strand), monitors
//   restart cleanly, and the scoreboard segments its witnesses on the reset
//   boundary so only the post-reset attempt is graded. Defaults already expect
//   a full successful handshake (the second attempt).
// ---------------------------------------------------------------------------
class test_sbinit_reset extends sbinit_base_test;
  `uvm_component_utils(test_sbinit_reset)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    sbinit_reset_recovery_vseq vseq;
    phase.raise_objection(this, "test_sbinit_reset");

    `uvm_info("TEST",
              "Starting test_sbinit_reset: inject a mid-flight reset, then complete a clean SBINIT handshake",
              UVM_LOW)

    vseq = sbinit_reset_recovery_vseq::type_id::create("vseq");
    vseq.start(env.vseqr);

    #(`SBINIT_DRAIN_NS);
    `uvm_info("TEST", "test_sbinit_reset stimulus complete; entering check_phase", UVM_LOW)
    phase.drop_objection(this, "test_sbinit_reset");
  endtask
endclass

// ---------------------------------------------------------------------------
// test_sbinit_random
//   Randomized regression: runs several full SBINIT handshakes with randomized
//   timing, separated by resets, in a single simulation. Broadens timing,
//   repetition, and reset-boundary coverage. Each run is a valid exchange, so
//   the witness scoreboard, reference-model predictor, and assertions all stay
//   green. Use the simulator seed to vary the scenario across regression runs:
//     make sbinit SBTEST=test_sbinit_random
// ---------------------------------------------------------------------------
class test_sbinit_random extends sbinit_base_test;
  `uvm_component_utils(test_sbinit_random)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    sbinit_random_vseq vseq;
    phase.raise_objection(this, "test_sbinit_random");

    `uvm_info("TEST",
              "Starting test_sbinit_random: randomized multi-run SBINIT regression",
              UVM_LOW)

    vseq = sbinit_random_vseq::type_id::create("vseq");
    vseq.start(env.vseqr);

    #(`SBINIT_DRAIN_NS);
    `uvm_info("TEST", "test_sbinit_random stimulus complete; entering check_phase", UVM_LOW)
    phase.drop_objection(this, "test_sbinit_random");
  endtask
endclass

`endif
