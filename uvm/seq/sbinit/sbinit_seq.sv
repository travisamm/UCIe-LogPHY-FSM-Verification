`ifndef SBINIT_SEQ_SV
`define SBINIT_SEQ_SV

// ---------------------------------------------------------------------------
// SBINIT virtual sequences
// ---------------------------------------------------------------------------
// One vseq per test. Each walks the SBINIT protocol from the test-bench side
// using the split drive channels exposed by sbinit_base_vseq:
//   * drive_req_rx / drive_rsp_rx  — partner -> DUT data (rx channels)
//   * set_req_tx_ready / set_rsp_tx_ready — back-pressure (tx-ready channels)
//   * kick_fsm_start / req_rx_idle — FSM kick / idle helpers
//
// Because rx and tx-ready are independent sequencers, back-pressure can be
// applied concurrently with rx activity by forking the two helpers.
//
// All messages are built with sbinit_sb_msg::pack() via make_no_data_msg().
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// sbinit_sanity_vseq
//   Happy-path handshake: clock-pattern emission, partner sampling, pattern
//   stop on detection, mode transition, Out-of-Reset, done req/resp.
// ---------------------------------------------------------------------------
class sbinit_sanity_vseq extends sbinit_base_vseq;
  `uvm_object_utils(sbinit_sanity_vseq)

  function new(string name = "sbinit_sanity_vseq");
    super.new(name);
  endfunction

  virtual task body();
    logic [127:0] out_of_reset;
    logic [127:0] done_resp;
    logic [127:0] done_req;

    out_of_reset = make_no_data_msg(SBINIT_MC_OUT_OF_RESET, SBINIT_SC_OOR);
    done_resp    = make_no_data_msg(SBINIT_MC_DONE_RESP,    SBINIT_SC_DONE);
    done_req     = make_no_data_msg(SBINIT_MC_DONE_REQ,     SBINIT_SC_DONE);

    // Kick the FSM and stream the partner's 64-UI clock pattern. fsm_start is
    // held until the OoR item below drops it (after the FSM leaves sPATTERN).
    drive_req_rx(SBINIT_CLK_PATTERN_5, .delay(10), .hold(5), .fsm_start(1));

    // Partner sends {SBINIT Out of Reset}; tx_ready stays high (default).
    drive_req_rx(out_of_reset, .delay(20), .hold(5));

    // Partner closes the handshake on both lanes.
    drive_req_rx(done_resp, .delay(20), .hold(5));
    drive_rsp_rx(done_req,  .delay(0),  .hold(5));

    wait_for_fsm_done();
  endtask
endclass

// ---------------------------------------------------------------------------
// sbinit_timeout_vseq
//   Kick the FSM and drive nothing. fsmCtrl_error is hardcoded 0 in this RTL,
//   so the FSM just stalls; the scoreboard confirms fsmCtrl_done never asserts.
// ---------------------------------------------------------------------------
class sbinit_timeout_vseq extends sbinit_base_vseq;
  `uvm_object_utils(sbinit_timeout_vseq)

  // Cycles to hold the FSM kicked with no stimulus before returning.
  int unsigned stall_cycles = 500;

  function new(string name = "sbinit_timeout_vseq");
    super.new(name);
  endfunction

  virtual task body();
    kick_fsm_start(.delay(5), .hold(stall_cycles));
    // Not expected to assert done; give a brief watchdog window only.
    wait_for_fsm_done(.timeout_ns(2000));
  endtask
endclass

// ---------------------------------------------------------------------------
// sbinit_partner_not_ready_vseq
//   Long gap between clock pattern and partner {Out of Reset}; verifies the
//   DUT keeps emitting its own {Out of Reset} until the partner responds.
// ---------------------------------------------------------------------------
class sbinit_partner_not_ready_vseq extends sbinit_base_vseq;
  `uvm_object_utils(sbinit_partner_not_ready_vseq)

  function new(string name = "sbinit_partner_not_ready_vseq");
    super.new(name);
  endfunction

  virtual task body();
    logic [127:0] out_of_reset;
    logic [127:0] done_resp;
    logic [127:0] done_req;

    out_of_reset = make_no_data_msg(SBINIT_MC_OUT_OF_RESET, SBINIT_SC_OOR);
    done_resp    = make_no_data_msg(SBINIT_MC_DONE_RESP,    SBINIT_SC_DONE);
    done_req     = make_no_data_msg(SBINIT_MC_DONE_REQ,     SBINIT_SC_DONE);

    drive_req_rx(SBINIT_CLK_PATTERN_5, .delay(10), .hold(5), .fsm_start(1));

    // Big gap so the DUT must hold {Out of Reset} steady for many cycles.
    drive_req_rx(out_of_reset, .delay(500), .hold(5));

    drive_req_rx(done_resp, .delay(20), .hold(5));
    drive_rsp_rx(done_req,  .delay(0),  .hold(5));

    wait_for_fsm_done();
  endtask
endclass

// ---------------------------------------------------------------------------
// sbinit_early_req_vseq
//   Partner sends {SBINIT done req} on the responder RX before the DUT has
//   emitted its {Out of Reset}. The DUT must ignore the premature request and
//   complete only once the proper sequence follows.
// ---------------------------------------------------------------------------
class sbinit_early_req_vseq extends sbinit_base_vseq;
  `uvm_object_utils(sbinit_early_req_vseq)

  function new(string name = "sbinit_early_req_vseq");
    super.new(name);
  endfunction

  virtual task body();
    logic [127:0] out_of_reset;
    logic [127:0] done_resp;
    logic [127:0] done_req;

    out_of_reset = make_no_data_msg(SBINIT_MC_OUT_OF_RESET, SBINIT_SC_OOR);
    done_resp    = make_no_data_msg(SBINIT_MC_DONE_RESP,    SBINIT_SC_DONE);
    done_req     = make_no_data_msg(SBINIT_MC_DONE_REQ,     SBINIT_SC_DONE);

    drive_req_rx(SBINIT_CLK_PATTERN_5, .delay(10), .hold(5), .fsm_start(1));

    // Premature done req: DUT must ignore it.
    drive_rsp_rx(done_req, .delay(20), .hold(5));

    // Now drive the proper sequence.
    drive_req_rx(out_of_reset, .delay(20), .hold(5));
    drive_req_rx(done_resp,    .delay(20), .hold(5));
    drive_rsp_rx(done_req,     .delay(0),  .hold(5));

    wait_for_fsm_done();
  endtask
endclass

// ---------------------------------------------------------------------------
// sbinit_collapse_reqs_vseq
//   Hold responder tx_ready low (its own channel) so the DUT's done response
//   is back-pressured, then push multiple {done req} bursts. The DUT should
//   collapse them into a single {done resp} once ready is released.
// ---------------------------------------------------------------------------
class sbinit_collapse_reqs_vseq extends sbinit_base_vseq;
  `uvm_object_utils(sbinit_collapse_reqs_vseq)

  // Number of duplicate {done req} bursts the partner sends.
  int unsigned num_dupes = 3;

  function new(string name = "sbinit_collapse_reqs_vseq");
    super.new(name);
  endfunction

  virtual task body();
    logic [127:0] out_of_reset;
    logic [127:0] done_resp;
    logic [127:0] done_req;

    out_of_reset = make_no_data_msg(SBINIT_MC_OUT_OF_RESET, SBINIT_SC_OOR);
    done_resp    = make_no_data_msg(SBINIT_MC_DONE_RESP,    SBINIT_SC_DONE);
    done_req     = make_no_data_msg(SBINIT_MC_DONE_REQ,     SBINIT_SC_DONE);

    drive_req_rx(SBINIT_CLK_PATTERN_5, .delay(10), .hold(5), .fsm_start(1));

    // Requester tx_ready stays HIGH so the DUT can emit its own Out-of-Reset.
    drive_req_rx(out_of_reset, .delay(20), .hold(5));

    // Back-pressure ONLY the responder TX via its tx-ready channel. The level
    // persists across the done-req bursts that follow on the rx channel.
    set_rsp_tx_ready(.level(0));

    // Fire num_dupes consecutive done-req bursts, each separated by a few idle
    // cycles so the scoreboard edge-detector counts them distinctly.
    repeat (num_dupes)
      drive_rsp_rx(done_req, .delay(5), .hold(2));

    // Release responder back-pressure and let the DUT complete.
    set_rsp_tx_ready(.level(1));
    drive_req_rx(done_resp, .delay(20), .hold(5));

    wait_for_fsm_done();
  endtask
endclass

// ---------------------------------------------------------------------------
// sbinit_req_backpressure_vseq
//   Exercises the requester-side ready/valid stability of SBInitRequester
//   while the DUT is trying to emit {SBINIT Out of Reset}: holds requester
//   tx_ready LOW for a window after the FSM enters sOUT_OF_RESET, then
//   releases it and completes the handshake.
//
//   With a correct DUT, the partner sees a stable {SBINIT Out of Reset} on
//   tx_data the whole time tx_valid is high (data-stability check + SB-06
//   PASS). With the current RTL (SBInit.scala lines 128-132) tx_data is only
//   driven inside `when(tx.ready)`, so the window produces tx_valid=1 with
//   tx_data=0 and the scoreboard's data-stability check fires. EXPECTED TO
//   FAIL until the RTL fix lands.
//
//   Now that tx_ready has its own channel, the back-pressure is a genuinely
//   concurrent activity: the tx-ready thread holds tx_ready low on its own
//   sequencer while the rx thread idles, and a third thread closes the
//   responder handshake. Threads rendezvous on events:
//     clk_pattern_done  rx -> txready : FSM is in sOUT_OF_RESET, drop ready
//     bp_released       txready -> rx : back-pressure window finished
//     oor_exchanged     rx -> rsp     : requester acked OoR, responder closes
// ---------------------------------------------------------------------------
class sbinit_req_backpressure_vseq extends sbinit_base_vseq;
  `uvm_object_utils(sbinit_req_backpressure_vseq)

  // Cycles to hold requester tx_ready LOW once the FSM is in sOUT_OF_RESET.
  int unsigned backpressure_hold_cycles = 30;

  function new(string name = "sbinit_req_backpressure_vseq");
    super.new(name);
  endfunction

  virtual task body();
    logic [127:0] out_of_reset;
    logic [127:0] done_resp;
    logic [127:0] done_req;
    event         clk_pattern_done;
    event         bp_released;
    event         oor_exchanged;

    out_of_reset = make_no_data_msg(SBINIT_MC_OUT_OF_RESET, SBINIT_SC_OOR);
    done_resp    = make_no_data_msg(SBINIT_MC_DONE_RESP,    SBINIT_SC_DONE);
    done_req     = make_no_data_msg(SBINIT_MC_DONE_REQ,     SBINIT_SC_DONE);

    fork
      // ----- RX channel: clock pattern, then idle through OoR, then close ---
      begin : rx_thread
        // Kick + clock pattern (fsm_start held high).
        drive_req_rx(SBINIT_CLK_PATTERN_5, .delay(10), .hold(5), .fsm_start(1));
        // Idle with fsm_start still high (tx_ready is high by default here) so
        // fourPatternCounter reaches 3 and the FSM enters sOUT_OF_RESET.
        req_rx_idle(.hold(10), .fsm_start(1));
        ->clk_pattern_done;

        // Wait out the back-pressure window (rx stays idle: partner has not
        // yet acked the DUT's Out-of-Reset).
        @bp_released;

        // Release done: drive the partner's Out-of-Reset, then done_resp.
        drive_req_rx(out_of_reset, .delay(5), .hold(5));
        ->oor_exchanged;
        drive_req_rx(done_resp, .delay(20), .hold(5));
      end

      // ----- TX-ready channel: hold requester back-pressure concurrently ----
      begin : txready_thread
        @clk_pattern_done;
        set_req_tx_ready(.level(0), .hold(backpressure_hold_cycles));
        set_req_tx_ready(.level(1));
        ->bp_released;
      end

      // ----- Responder lane: close the handshake concurrently ---------------
      begin : rsp_thread
        @oor_exchanged;
        drive_rsp_rx(done_req, .delay(0), .hold(5));
      end
    join

    wait_for_fsm_done();
  endtask
endclass

// ---------------------------------------------------------------------------
// sbinit_rsp_backpressure_vseq
//   Responder-side analog of sbinit_req_backpressure_vseq, exercising the
//   ready/valid stability of SBInitResponder. The responder only owes a
//   {done resp} once (a) the requester has reached sSBINIT_DONE_MSG, which
//   asserts responder.start, and (b) a {done req} has arrived on the
//   responder RX. We hold the responder tx_ready LOW across that window so
//   the responder asserts tx_valid while it cannot complete the handshake.
//
//   With a correct DUT the responder holds the {done resp} payload on tx_data
//   the whole time tx_valid is high. With the current RTL (SBInit.scala
//   lines 183-187 assign tx.bits.data inside `when(tx.ready)`) it drives
//   tx_valid=1 with tx_data=0 during the window, tripping the scoreboard's
//   responder data-stability check. EXPECTED TO FAIL until the RTL fix lands.
//
//   The requester is walked into sSBINIT_DONE_MSG sequentially BEFORE the
//   fork, so responder.start is already asserted when the concurrent phase
//   begins. The tx-ready channel then makes the back-pressure genuinely
//   concurrent: one thread holds rsp tx_ready low on its own sequencer while a
//   second delivers the done_req on the responder RX and a third closes the
//   requester's receive side.
// ---------------------------------------------------------------------------
class sbinit_rsp_backpressure_vseq extends sbinit_base_vseq;
  `uvm_object_utils(sbinit_rsp_backpressure_vseq)

  // Cycles to hold responder tx_ready LOW while it owes a {done resp}.
  int unsigned backpressure_hold_cycles = 30;

  function new(string name = "sbinit_rsp_backpressure_vseq");
    super.new(name);
  endfunction

  virtual task body();
    logic [127:0] out_of_reset;
    logic [127:0] done_resp;
    logic [127:0] done_req;

    out_of_reset = make_no_data_msg(SBINIT_MC_OUT_OF_RESET, SBINIT_SC_OOR);
    done_resp    = make_no_data_msg(SBINIT_MC_DONE_RESP,    SBINIT_SC_DONE);
    done_req     = make_no_data_msg(SBINIT_MC_DONE_REQ,     SBINIT_SC_DONE);

    // Setup: walk the requester into sSBINIT_DONE_MSG so responder.start is
    // asserted. fsm_start is held through the clock pattern and dropped by the
    // OoR item's delay, after the FSM has left sPATTERN.
    drive_req_rx(SBINIT_CLK_PATTERN_5, .delay(10), .hold(5), .fsm_start(1));
    drive_req_rx(out_of_reset, .delay(20), .hold(5));

    fork
      // ----- Requester lane: finish the requester's own receive side -------
      begin : req_lane
        drive_req_rx(done_resp, .delay(20), .hold(5));
      end

      // ----- TX-ready channel: hold responder back-pressure concurrently ----
      // Assert tx_ready LOW first (and keep it low across the window) so it is
      // already low when the responder asserts tx_valid after the done_req.
      begin : rsp_txready_thread
        set_rsp_tx_ready(.level(0), .hold(backpressure_hold_cycles));
        set_rsp_tx_ready(.level(1));
      end

      // ----- Responder RX: deliver the done_req that creates the owed resp --
      // Small delay so the tx_ready=0 level is established first.
      begin : rsp_rx_thread
        drive_rsp_rx(done_req, .delay(2), .hold(5));
      end
    join

    wait_for_fsm_done();
  endtask
endclass

// ---------------------------------------------------------------------------
// sbinit_reset_recovery_vseq
//   Mid-sim reset recovery. Two attempts:
//     1. Kick the FSM and start streaming the clock pattern, then inject a
//        reset WHILE that rx item is in flight. The reset-aware drivers must
//        abort the drive, idle their outputs, and complete the UVM item
//        handshake (otherwise this vseq would hang at the forked drive_req_rx).
//     2. After reset releases, run a clean, full SBINIT handshake to
//        completion. The scoreboard segments on the reset boundary, so the
//        summary reflects only this second attempt.
//
//   Proves: drivers do not strand items across reset; monitors restart event
//   observation cleanly; scoreboard does not reuse pre-reset witnesses; the
//   reset boundary is centralized through the reset monitor.
// ---------------------------------------------------------------------------
class sbinit_reset_recovery_vseq extends sbinit_base_vseq;
  `uvm_object_utils(sbinit_reset_recovery_vseq)

  function new(string name = "sbinit_reset_recovery_vseq");
    super.new(name);
  endfunction

  virtual task body();
    logic [127:0] out_of_reset;
    logic [127:0] done_resp;
    logic [127:0] done_req;

    out_of_reset = make_no_data_msg(SBINIT_MC_OUT_OF_RESET, SBINIT_SC_OOR);
    done_resp    = make_no_data_msg(SBINIT_MC_DONE_RESP,    SBINIT_SC_DONE);
    done_req     = make_no_data_msg(SBINIT_MC_DONE_REQ,     SBINIT_SC_DONE);

    // ---- Attempt 1: start, then reset mid-flight ----
    // A long clock-pattern drive runs concurrently with a reset pulse that
    // lands while the rx item is in flight. join completes only if the rx
    // driver releases the aborted item (no strand) and pulse_reset returns
    // after reset falls low.
    fork
      begin : partial
        drive_req_rx(SBINIT_CLK_PATTERN_5, .delay(5), .hold(50), .fsm_start(1));
      end
      begin : inject
        pulse_reset(.delay(15), .cycles(5));
      end
    join

    // ---- Attempt 2: clean full SBINIT to completion ----
    drive_req_rx(SBINIT_CLK_PATTERN_5, .delay(10), .hold(5), .fsm_start(1));
    drive_req_rx(out_of_reset, .delay(20), .hold(5));
    drive_req_rx(done_resp,    .delay(20), .hold(5));
    drive_rsp_rx(done_req,     .delay(0),  .hold(5));

    wait_for_fsm_done();
  endtask
endclass

`endif
