`ifndef SBINIT_BASE_VSEQ_SV
`define SBINIT_BASE_VSEQ_SV

// ---------------------------------------------------------------------------
// sbinit_base_vseq
// ---------------------------------------------------------------------------
// Common virtual-sequence machinery for the SBINIT suite:
//   * handles to the four real sequencers — rx and tx-ready, per lane
//   * a control-bus handle so body() can wait on protocol events (done/error)
//   * helpers for building SBINIT messages and pushing rx / tx-ready items
//
// The rx and tx-ready channels are independent sequencers, so a derived
// sequence can hold back-pressure (set_*_tx_ready) concurrently with rx
// activity (drive_*_rx) by forking the two helpers.
//
// Concrete sequences extend this class, get their seqr handles wired from
// env.vseqr by the test, and call .start(env.vseqr).
// ---------------------------------------------------------------------------

class sbinit_base_vseq extends uvm_sequence #(uvm_sequence_item);
  `uvm_object_utils(sbinit_base_vseq)

  // Drive-channel sequencers (wired from env.vseqr by the test).
  sbinit_req_rx_sequencer  req_rx_seqr;
  sbinit_txready_sequencer req_txready_seqr;
  sbinit_rsp_rx_sequencer  rsp_rx_seqr;
  sbinit_txready_sequencer rsp_txready_seqr;
  sbinit_reset_sequencer   reset_seqr;

  // Sampled in pre_body() so derived sequences can wait on protocol events.
  virtual sb_ctrl_if ctrl_vif;

  function new(string name = "sbinit_base_vseq");
    super.new(name);
  endfunction

  // -------- protocol-time hooks ------------------------------------------
  virtual task pre_body();
    if (!uvm_config_db#(virtual sb_ctrl_if)::get(null, "*", "sbinit_ctrl_vif", ctrl_vif))
      `uvm_fatal("VSEQ", "sbinit_base_vseq: could not get sbinit_ctrl_vif from config_db")
  endtask

  // Wait until the DUT raises fsmCtrl_done (or fsmCtrl_error), or a watchdog
  // fires. timeout_ns is in nanoseconds; the package default timescale is 1ns.
  task wait_for_fsm_done(int timeout_ns = 20000);
    bit timed_out = 0;
    fork
      begin
        wait (ctrl_vif.fsmCtrl_done === 1'b1 || ctrl_vif.fsmCtrl_error === 1'b1);
      end
      begin
        #(timeout_ns);
        timed_out = 1;
      end
    join_any
    disable fork;
    if (timed_out)
      `uvm_info("VSEQ",
                $sformatf("Watchdog: fsmCtrl_done/error did not assert within %0d ns",
                          timeout_ns), UVM_MEDIUM)
  endtask

  // -------- low-level item senders ---------------------------------------
  task send_req_rx(sbinit_req_rx_transaction t);
    start_item(t, -1, req_rx_seqr);
    finish_item(t, -1);
  endtask

  task send_rsp_rx(sbinit_rsp_rx_transaction t);
    start_item(t, -1, rsp_rx_seqr);
    finish_item(t, -1);
  endtask

  task send_req_txready(sbinit_txready_transaction t);
    start_item(t, -1, req_txready_seqr);
    finish_item(t, -1);
  endtask

  task send_rsp_txready(sbinit_txready_transaction t);
    start_item(t, -1, rsp_txready_seqr);
    finish_item(t, -1);
  endtask

  task send_reset(sbinit_reset_transaction t);
    start_item(t, -1, reset_seqr);
    finish_item(t, -1);
  endtask

  // -------- message-builder helper ---------------------------------------
  // Compose a 128-bit "no-data" SBINIT message using sbinit_sb_msg::pack().
  function logic [127:0] make_no_data_msg(bit [7:0] mc, bit [7:0] sc);
    sbinit_sb_msg m;
    m          = new();
    m.opcode   = SBINIT_OP_NO_DATA;
    m.msg_code = mc;
    m.subcode  = sc;
    return m.pack();
  endfunction

  // -------- requester rx helpers -----------------------------------------
  // Pulse fsmCtrl_start (held across the item) with no rx data.
  task kick_fsm_start(int delay = 10, int hold = 5);
    sbinit_req_rx_transaction t;
    t               = sbinit_req_rx_transaction::type_id::create("kick");
    t.fsmCtrl_start = 1;
    t.delay         = delay;
    t.hold_cycles   = hold;
    send_req_rx(t);
  endtask

  // Drive a payload on the requester RX lane. fsm_start lets the caller keep
  // the FSM kick asserted (needed until the FSM leaves sPATTERN).
  task drive_req_rx(logic [127:0] data, int delay = 5, int hold = 5,
                    bit fsm_start = 0);
    sbinit_req_rx_transaction t;
    t               = sbinit_req_rx_transaction::type_id::create("req_rx");
    t.rx_valid      = 1;
    t.rx_data       = data;
    t.fsmCtrl_start = fsm_start;
    t.delay         = delay;
    t.hold_cycles   = hold;
    send_req_rx(t);
  endtask

  // Idle the requester RX lane (rx_valid low) for `hold` cycles, optionally
  // holding fsmCtrl_start asserted so the FSM keeps advancing through sPATTERN.
  task req_rx_idle(int hold = 1, bit fsm_start = 0);
    sbinit_req_rx_transaction t;
    t               = sbinit_req_rx_transaction::type_id::create("req_rx_idle");
    t.rx_valid      = 0;
    t.fsmCtrl_start = fsm_start;
    t.delay         = 0;
    t.hold_cycles   = hold;
    send_req_rx(t);
  endtask

  // -------- responder rx helper ------------------------------------------
  task drive_rsp_rx(logic [127:0] data, int delay = 5, int hold = 5);
    sbinit_rsp_rx_transaction t;
    t             = sbinit_rsp_rx_transaction::type_id::create("rsp_rx");
    t.rx_valid    = 1;
    t.rx_data     = data;
    t.delay       = delay;
    t.hold_cycles = hold;
    send_rsp_rx(t);
  endtask

  // -------- tx-ready (back-pressure) helpers -----------------------------
  // Set the requester/responder tx_ready LEVEL. It persists until changed.
  task set_req_tx_ready(bit level, int delay = 0, int hold = 1);
    sbinit_txready_transaction t;
    t             = sbinit_txready_transaction::type_id::create("req_txready");
    t.tx_ready    = level;
    t.delay       = delay;
    t.hold_cycles = hold;
    send_req_txready(t);
  endtask

  task set_rsp_tx_ready(bit level, int delay = 0, int hold = 1);
    sbinit_txready_transaction t;
    t             = sbinit_txready_transaction::type_id::create("rsp_txready");
    t.tx_ready    = level;
    t.delay       = delay;
    t.hold_cycles = hold;
    send_rsp_txready(t);
  endtask

  // -------- reset-injection helper ---------------------------------------
  // Inject a reset pulse: wait `delay` cycles, hold the DUT in reset for
  // `cycles`, release. Blocks until the combined reset has fallen low again so
  // the caller can safely start a fresh attempt afterwards.
  task pulse_reset(int delay = 0, int cycles = 5);
    sbinit_reset_transaction t;
    t        = sbinit_reset_transaction::type_id::create("reset");
    t.delay  = delay;
    t.cycles = cycles;
    send_reset(t);
    wait (ctrl_vif.reset === 1'b0);
  endtask

  virtual task body();
  endtask

endclass

`endif
