`ifndef SBINIT_BASE_VSEQ_SV
`define SBINIT_BASE_VSEQ_SV

// ---------------------------------------------------------------------------
// sbinit_base_vseq
// ---------------------------------------------------------------------------
// Common virtual-sequence machinery for the SBINIT suite:
//   * handles to the two real sequencers (req + rsp)
//   * a virtual-interface handle so body() can wait on the protocol
//   * thin helpers for building SBINIT messages (via sbinit_sb_msg::pack)
//     and pushing them onto either sequencer
//
// Concrete sequences extend this class and provide their own body().
// Tests construct one of them, wire the seqr handles from env.vseqr, and
// call .start(env.vseqr).
// ---------------------------------------------------------------------------

class sbinit_base_vseq extends uvm_sequence #(uvm_sequence_item);
  `uvm_object_utils(sbinit_base_vseq)

  sbinit_req_sequencer req_seqr;
  sbinit_rsp_sequencer rsp_seqr;

  // Sampled in pre_body() so derived sequences can wait on protocol events.
  // Only the FSM control bus is needed here (done/error).
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
  // fires. Returns immediately if `done` is already high.
  // timeout_ns is in nanoseconds; the package's default timescale is 1ns.
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

  // -------- low-level item drive -----------------------------------------
  task send_req_item(sbinit_req_transaction t);
    start_item(t, -1, req_seqr);
    finish_item(t, -1);
  endtask

  task send_rsp_item(sbinit_rsp_transaction t);
    start_item(t, -1, rsp_seqr);
    finish_item(t, -1);
  endtask

  // -------- message-builder helpers --------------------------------------
  // Compose a 128-bit "no-data" SBINIT message using sbinit_sb_msg::pack().
  function logic [127:0] make_no_data_msg(bit [7:0] mc, bit [7:0] sc);
    sbinit_sb_msg m;
    m          = new();
    m.opcode   = SBINIT_OP_NO_DATA;
    m.msg_code = mc;
    m.subcode  = sc;
    return m.pack();
  endfunction

  // -------- high-level requester-side drive ------------------------------
  // Pulse fsmCtrl_start for `hold` cycles, optionally with an upstream delay.
  task kick_fsm_start(int delay = 10, int hold = 5);
    sbinit_req_transaction t;
    t               = sbinit_req_transaction::type_id::create("kick");
    t.fsmCtrl_start = 1;
    t.delay         = delay;
    t.hold_cycles   = hold;
    send_req_item(t);
  endtask

  // Drive a payload on the requester RX lane for `hold` cycles.
  task drive_req_rx(logic [127:0] data, int delay = 5, int hold = 5,
                    bit tx_ready = 1, bit fsm_start = 0);
    sbinit_req_transaction t;
    t               = sbinit_req_transaction::type_id::create("req_rx");
    t.rx_valid      = 1;
    t.rx_data       = data;
    t.tx_ready      = tx_ready;
    t.fsmCtrl_start = fsm_start;
    t.delay         = delay;
    t.hold_cycles   = hold;
    send_req_item(t);
  endtask

  // Drive a payload on the responder RX lane.
  task drive_rsp_rx(logic [127:0] data, int delay = 5, int hold = 5,
                    bit tx_ready = 1);
    sbinit_rsp_transaction t;
    t             = sbinit_rsp_transaction::type_id::create("rsp_rx");
    t.rx_valid    = 1;
    t.rx_data     = data;
    t.tx_ready    = tx_ready;
    t.delay       = delay;
    t.hold_cycles = hold;
    send_rsp_item(t);
  endtask

  // Idle the responder lane with a configurable tx_ready level (e.g. force
  // back-pressure on the DUT's outgoing done response).
  task rsp_set_tx_ready(bit ready, int delay = 0, int hold = 1);
    sbinit_rsp_transaction t;
    t             = sbinit_rsp_transaction::type_id::create("rsp_ready");
    t.rx_valid    = 0;
    t.tx_ready    = ready;
    t.delay       = delay;
    t.hold_cycles = hold;
    send_rsp_item(t);
  endtask

  virtual task body();
  endtask

endclass

`endif
