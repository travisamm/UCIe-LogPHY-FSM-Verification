`ifndef MBINIT_RESET_MONITOR_SV
`define MBINIT_RESET_MONITOR_SV

// ---------------------------------------------------------------------------
// mbinit_reset_monitor  (Pass 4)
// ---------------------------------------------------------------------------
// The single reset-event source for MBINIT. Observes the combined DUT reset
// (mb_reset_if's `reset` input) and emits boundary events on the common
// mbinit_event stream:
//   * MB_EVT_RESET_ASSERTED   on reset 0 -> 1
//   * MB_EVT_RESET_DEASSERTED on reset 1 -> 0
// Assumes POR asserted at t=0, so the first transition emitted after release
// is DEASSERTED (not a spurious ASSERTED).
//
// All other monitors suppress their events while reset is high, so between an
// ASSERTED and the following DEASSERTED no protocol events appear.
// ---------------------------------------------------------------------------
class mbinit_reset_monitor extends uvm_monitor;
  `uvm_component_utils(mbinit_reset_monitor)

  virtual mb_reset_if vif;
  uvm_analysis_port #(mbinit_event) ev_ap;

  protected int unsigned seq_counter;
  protected logic        prev_reset;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ev_ap = new("ev_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mb_reset_if)::get(this, "", "mbinit_reset_vif", vif))
      `uvm_fatal("NO_VIF", {"mbinit_reset_vif must be set for: ", get_full_name()})
  endfunction

  protected function void emit(mbinit_evt_kind_e k);
    mbinit_event ev;
    ev          = mbinit_event::type_id::create("ev");
    ev.kind     = k;
    ev.src      = MB_SRC_RESET;
    ev.dir      = MB_DIR_NA;
    ev.phase    = MB_PHASE_OBSERVED;
    ev.svc_kind = MB_SVC_NONE;
    ev.layout   = MB_LAYOUT_NONE;
    ev.tstamp   = $realtime;
    seq_counter++;
    ev.seq_num  = seq_counter;
    ev_ap.write(ev);
  endfunction

  task run_phase(uvm_phase phase);
    logic r;
    prev_reset = 1'b1;  // POR assumption
    forever begin
      @(vif.mon_cb);
      r = vif.mon_cb.reset;
      if ((r === 1'b1) && (prev_reset !== 1'b1)) emit(MB_EVT_RESET_ASSERTED);
      if ((r !== 1'b1) && (prev_reset === 1'b1)) emit(MB_EVT_RESET_DEASSERTED);
      prev_reset = r;
    end
  endtask

endclass

`endif
