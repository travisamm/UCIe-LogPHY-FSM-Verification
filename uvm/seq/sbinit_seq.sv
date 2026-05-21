`ifndef SBINIT_SEQ_SV
`define SBINIT_SEQ_SV

// ---------------------------------------------------------------------------
// SBINIT virtual sequences
// ---------------------------------------------------------------------------
// One vseq per test. Each one walks the SBINIT protocol from the test bench
// side: kicks the DUT, drives the partner's clock pattern, sends the partner
// {Out of Reset} / {done resp} / {done req} messages as the scenario
// dictates, and (where applicable) waits for fsmCtrl_done before returning.
//
// All messages are built with sbinit_sb_msg::pack() via the helpers in
// sbinit_base_vseq, so the test reads as protocol intent instead of hex.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// sbinit_sanity_vseq
//   Happy-path handshake. Exercises clock-pattern emission, partner sampling,
//   pattern stop on detection, mode transition, Out-of-Reset transmission,
//   and the done req/resp exchange.
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

    // 1) Kick the FSM and stream the partner's 64-UI clock pattern on the
    //    requester RX lane simultaneously.
    begin
      sbinit_req_transaction t;
      t               = sbinit_req_transaction::type_id::create("kick_and_clk");
      t.fsmCtrl_start = 1;
      t.rx_valid      = 1;
      t.rx_data       = SBINIT_CLK_PATTERN_5;
      t.delay         = 10;
      t.hold_cycles   = 5;
      send_req_item(t);
    end

    // 2) Partner sends {SBINIT Out of Reset} so DUT can advance to the done
    //    exchange.
    drive_req_rx(out_of_reset, .delay(20), .hold(5));

    // 3) Partner sends {SBINIT done resp} on the requester RX and {SBINIT
    //    done req} on the responder RX. DUT exits to MBINIT.
    drive_req_rx(done_resp,   .delay(20), .hold(5));
    drive_rsp_rx(done_req,    .delay(0),  .hold(5));

    wait_for_fsm_done();
  endtask
endclass

// ---------------------------------------------------------------------------
// sbinit_timeout_vseq
//   Kick the FSM and drive nothing. DUT is supposed to time out to
//   TRAINERROR after ~8 ms. fsmCtrl_error is hardcoded to 0 in this RTL, so
//   in practice the FSM just stalls; the test relies on the scoreboard to
//   confirm fsmCtrl_done never asserts.
// ---------------------------------------------------------------------------
class sbinit_timeout_vseq extends sbinit_base_vseq;
  `uvm_object_utils(sbinit_timeout_vseq)

  // Stall duration (cycles) after kicking start before returning from body.
  // Long enough to see the FSM idle without driving stimulus, short enough
  // to not blow up wall-clock sim time.
  int unsigned stall_cycles = 500;

  function new(string name = "sbinit_timeout_vseq");
    super.new(name);
  endfunction

  virtual task body();
    sbinit_req_transaction kick;
    kick               = sbinit_req_transaction::type_id::create("kick");
    kick.fsmCtrl_start = 1;
    kick.rx_valid      = 0;
    kick.delay         = 5;
    kick.hold_cycles   = stall_cycles;
    send_req_item(kick);
    // Do NOT wait_for_fsm_done — timeout scenarios are not expected to
    // assert it. The test bench gives the FSM a brief watchdog window.
    wait_for_fsm_done(.timeout_ns(2000));
  endtask
endclass

// ---------------------------------------------------------------------------
// sbinit_partner_not_ready_vseq
//   Same as sanity but with a long gap between the clock pattern and the
//   partner's {Out of Reset}. Verifies the DUT keeps emitting {Out of
//   Reset} continuously until the partner finally responds.
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

    begin
      sbinit_req_transaction t;
      t               = sbinit_req_transaction::type_id::create("kick_and_clk");
      t.fsmCtrl_start = 1;
      t.rx_valid      = 1;
      t.rx_data       = SBINIT_CLK_PATTERN_5;
      t.delay         = 10;
      t.hold_cycles   = 5;
      send_req_item(t);
    end

    // Big gap so the DUT must hold {Out of Reset} steady for many cycles
    // before the partner finally drives one back.
    drive_req_rx(out_of_reset, .delay(500), .hold(5));

    drive_req_rx(done_resp,    .delay(20), .hold(5));
    drive_rsp_rx(done_req,     .delay(0),  .hold(5));

    wait_for_fsm_done();
  endtask
endclass

// ---------------------------------------------------------------------------
// sbinit_early_req_vseq
//   Partner sends a {SBINIT done req} on the responder RX BEFORE the DUT
//   has emitted its {Out of Reset}. The DUT must ignore the premature
//   request; the handshake completes only once the proper sequence is
//   driven afterwards.
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

    begin
      sbinit_req_transaction t;
      t               = sbinit_req_transaction::type_id::create("kick_and_clk");
      t.fsmCtrl_start = 1;
      t.rx_valid      = 1;
      t.rx_data       = SBINIT_CLK_PATTERN_5;
      t.delay         = 10;
      t.hold_cycles   = 5;
      send_req_item(t);
    end

    // Premature done req: DUT must ignore it.
    drive_rsp_rx(done_req,    .delay(20), .hold(5));

    // Now drive the proper sequence.
    drive_req_rx(out_of_reset, .delay(20), .hold(5));
    drive_req_rx(done_resp,    .delay(20), .hold(5));
    drive_rsp_rx(done_req,     .delay(0),  .hold(5));

    wait_for_fsm_done();
  endtask
endclass

// ---------------------------------------------------------------------------
// sbinit_collapse_reqs_vseq
//   Hold responder tx_ready low so the DUT's done response is back-pressured,
//   then push multiple {done req} messages from the partner. The DUT should
//   accept exactly one done response when ready is released.
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

    begin
      sbinit_req_transaction t;
      t               = sbinit_req_transaction::type_id::create("kick_and_clk");
      t.fsmCtrl_start = 1;
      t.rx_valid      = 1;
      t.rx_data       = SBINIT_CLK_PATTERN_5;
      t.delay         = 10;
      t.hold_cycles   = 5;
      send_req_item(t);
    end

    // Drop the partner's Out of Reset on the requester RX. Requester
    // tx_ready must stay HIGH (default) so the DUT can complete its own
    // Out-of-Reset transmission — back-pressure here would mask SB-06 and
    // also trip a latent RTL protocol bug in SBInitRequester.sOUT_OF_RESET
    // where tx.bits.data is only driven inside `when(tx.ready)`.
    drive_req_rx(out_of_reset, .delay(20), .hold(5));

    // Back-pressure ONLY the responder TX so the DUT's outgoing done
    // response stalls while multiple done reqs pile up on responder RX.
    rsp_set_tx_ready(.ready(0), .delay(0), .hold(1));

    // Fire `num_dupes` consecutive done-req bursts, each separated by a few
    // idle cycles so the scoreboard edge-detector counts them distinctly.
    repeat (num_dupes) begin
      sbinit_rsp_transaction t;
      t             = sbinit_rsp_transaction::type_id::create("dup_done_req");
      t.rx_valid    = 1;
      t.rx_data     = done_req;
      t.tx_ready    = 0;
      t.delay       = 5;
      t.hold_cycles = 2;
      send_rsp_item(t);
    end

    // Release back-pressure and let the DUT complete.
    rsp_set_tx_ready(.ready(1), .delay(0), .hold(1));
    drive_req_rx(done_resp, .delay(20), .hold(5));

    wait_for_fsm_done();
  endtask
endclass

// ---------------------------------------------------------------------------
// sbinit_req_backpressure_vseq
//   Exercises the requester-side ready/valid stability of SBInitRequester
//   while the DUT is trying to emit {SBINIT Out of Reset}. Holds the
//   requester's tx_ready low for a window after the FSM has entered the
//   sOUT_OF_RESET state, then releases it and completes the handshake.
//
//   With a correct DUT, the partner observes a stable {SBINIT Out of Reset}
//   on tx_data the whole time tx_valid is high, and the scoreboard logs
//   SB-06 + the data-stability check as PASS.
//
//   With the current RTL (SBInit.scala lines 128-132), the DUT only drives
//   tx_data inside `when(tx.ready)`, so the back-pressure window produces
//   tx_valid=1 with tx_data=0. The scoreboard's data-stability check fires,
//   and SB-06 (Out-of-Reset emission) fails because the DUT never gets a
//   chance to drive the proper payload before outOfResetDetected advances
//   the FSM past sOUT_OF_RESET.
//
//   This vseq is expected to FAIL the new data-stability check (and SB-06)
//   until the RTL fix lands. It does NOT touch responder back-pressure, so
//   it does not interact with the SB-09 collapse path.
// ---------------------------------------------------------------------------
class sbinit_req_backpressure_vseq extends sbinit_base_vseq;
  `uvm_object_utils(sbinit_req_backpressure_vseq)

  // Cycles to hold requester tx_ready LOW after the FSM has entered the
  // sOUT_OF_RESET state. Long enough to guarantee the bug surfaces on a
  // broken RTL but short enough to keep wall-clock sim time reasonable.
  int unsigned backpressure_hold_cycles = 30;

  function new(string name = "sbinit_req_backpressure_vseq");
    super.new(name);
  endfunction

  virtual task body();
    logic [127:0] out_of_reset;
    logic [127:0] done_resp;
    logic [127:0] done_req;

    out_of_reset = make_no_data_msg(SBINIT_MC_OUT_OF_RESET, SBINIT_SC_OOR);
    done_resp    = make_no_data_msg(SBINIT_MC_DONE_RESP,    SBINIT_SC_DONE);
    done_req     = make_no_data_msg(SBINIT_MC_DONE_REQ,     SBINIT_SC_DONE);

    // 1) Kick FSM and drive partner clock pattern with tx_ready HIGH so the
    //    DUT's clock-pattern stage progresses normally and ultimately
    //    transitions into sOUT_OF_RESET.
    begin
      sbinit_req_transaction t;
      t               = sbinit_req_transaction::type_id::create("kick_and_clk");
      t.fsmCtrl_start = 1;
      t.rx_valid      = 1;
      t.rx_data       = SBINIT_CLK_PATTERN_5;
      t.delay         = 10;
      t.hold_cycles   = 5;
      send_req_item(t);
    end

    // 2) Brief idle with tx_ready HIGH so fourPatternCounter can reach 3
    //    and the FSM cleanly enters sOUT_OF_RESET before we back-pressure.
    begin
      sbinit_req_transaction t;
      t             = sbinit_req_transaction::type_id::create("idle_to_oor");
      t.rx_valid    = 0;
      t.tx_ready    = 1;
      t.delay       = 10;
      t.hold_cycles = 1;
      send_req_item(t);
    end

    // 3) Back-pressure window. tx_ready LOW for `backpressure_hold_cycles`,
    //    rx_valid LOW so the partner has NOT yet acknowledged the DUT's
    //    Out-of-Reset. During this window the DUT should hold tx_valid=1
    //    with tx_data = {SBINIT Out of Reset}; with the RTL bug it holds
    //    tx_valid=1 with tx_data = 0.
    begin
      sbinit_req_transaction t;
      t             = sbinit_req_transaction::type_id::create("backpressure");
      t.rx_valid    = 0;
      t.tx_ready    = 0;
      t.delay       = 0;
      t.hold_cycles = backpressure_hold_cycles;
      send_req_item(t);
    end

    // 4) Release back-pressure and drive the partner's Out-of-Reset. A
    //    correct DUT will already have proper tx_data on the bus and the
    //    handshake completes immediately; a buggy DUT only NOW assigns
    //    the OoR payload (which may already be too late, since the
    //    partner's OoR drives outOfResetDetected the same cycle).
    drive_req_rx(out_of_reset, .delay(5), .hold(5), .tx_ready(1));

    // 5) Finish the handshake on both lanes.
    drive_req_rx(done_resp, .delay(20), .hold(5));
    drive_rsp_rx(done_req,  .delay(0),  .hold(5));

    wait_for_fsm_done();
  endtask
endclass

`endif
