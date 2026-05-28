`ifndef MBINIT_PTTEST_REQ_MONITOR_SV
`define MBINIT_PTTEST_REQ_MONITOR_SV

// ---------------------------------------------------------------------------
// mbinit_pttest_req_monitor  (Pass 4)
// ---------------------------------------------------------------------------
// Passive observer of mb_pttest_req_if (requester-side Tx point test). Emits
// MB_EVT_PTTEST on:
//   * start         0->1 : svc_kind = MB_SVC_START
//   * done          0->1 : svc_kind = MB_SVC_DONE
//   * results_valid 0->1 : svc_kind = MB_SVC_RESULT, pt_results carries the
//                          16-bit per-lane bits.
// Suppressed while reset is high. src = MB_SRC_PTTEST_REQ, dir = NA.
// ---------------------------------------------------------------------------
class mbinit_pttest_req_monitor extends uvm_monitor;
  `uvm_component_utils(mbinit_pttest_req_monitor)

  virtual mb_pttest_req_if vif;
  uvm_analysis_port #(mbinit_event) ev_ap;

  protected int unsigned seq_counter;
  protected logic        prev_start, prev_done, prev_rv;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ev_ap = new("ev_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mb_pttest_req_if)::get(this, "", "mbinit_pttest_req_vif", vif))
      `uvm_fatal("NO_VIF", {"mbinit_pttest_req_vif must be set for: ", get_full_name()})
  endfunction

  protected function void reset_state();
    prev_start = 1'b0;
    prev_done  = 1'b0;
    prev_rv    = 1'b0;
  endfunction

  protected function mbinit_event mk(mbinit_evt_svc_e sk);
    mbinit_event ev;
    ev          = mbinit_event::type_id::create("ev");
    ev.kind     = MB_EVT_PTTEST;
    ev.src      = MB_SRC_PTTEST_REQ;
    ev.dir      = MB_DIR_NA;
    ev.phase    = MB_PHASE_OBSERVED;
    ev.svc_kind = sk;
    ev.layout   = MB_LAYOUT_NONE;
    ev.tstamp   = $realtime;
    seq_counter++;
    ev.seq_num  = seq_counter;
    return ev;
  endfunction

  task run_phase(uvm_phase phase);
    mbinit_event ev;
    logic        s, d, rv;
    logic [15:0] bits;
    reset_state();
    forever begin
      @(vif.mon_cb);
      if (vif.reset === 1'b1) begin
        reset_state();
        continue;
      end
      s    = vif.mon_cb.start;
      d    = vif.mon_cb.done;
      rv   = vif.mon_cb.results_valid;
      bits = vif.mon_cb.results_bits;
      if ((s  === 1'b1) && (prev_start !== 1'b1)) ev_ap.write(mk(MB_SVC_START));
      if ((d  === 1'b1) && (prev_done  !== 1'b1)) ev_ap.write(mk(MB_SVC_DONE));
      if ((rv === 1'b1) && (prev_rv    !== 1'b1)) begin
        ev = mk(MB_SVC_RESULT);
        ev.pt_results = bits;
        ev_ap.write(ev);
      end
      prev_start = s;
      prev_done  = d;
      prev_rv    = rv;
    end
  endtask

endclass

`endif
