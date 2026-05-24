`ifndef SBINIT_RESET_MONITOR_SV
`define SBINIT_RESET_MONITOR_SV

// ---------------------------------------------------------------------------
// sbinit_reset_monitor
// ---------------------------------------------------------------------------
// The single reset-event source. Observes the combined DUT reset (sb_reset_if's
// `reset` input) and emits boundary events onto the common sbinit_event stream:
//   * SB_EVT_RESET_ASSERTED   on reset 0 -> 1
//   * SB_EVT_RESET_DEASSERTED on reset 1 -> 0
// Reset boundaries are naturally first-class: the lane/control monitors suppress
// their events while reset is high, so between an ASSERTED and the following
// DEASSERTED no protocol events appear, and the scoreboard segments its
// per-attempt witnesses on ASSERTED.
//
// Instantiated directly by the env (passive, no agent wrapper), like the
// control monitor.
// ---------------------------------------------------------------------------
class sbinit_reset_monitor extends uvm_monitor;
  `uvm_component_utils(sbinit_reset_monitor)

  virtual sb_reset_if vif;
  uvm_analysis_port #(sbinit_event) ev_ap;

  protected int unsigned seq_counter;
  protected logic        prev_reset;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ev_ap = new("ev_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual sb_reset_if)::get(this, "", "sbinit_reset_vif", vif))
      `uvm_fatal("NO_VIF", {"sbinit_reset_vif must be set for: ", get_full_name()})
  endfunction

  protected function void emit(sbinit_evt_kind_e k);
    sbinit_event ev;
    ev         = sbinit_event::type_id::create("ev");
    ev.kind    = k;
    ev.src     = SB_SRC_RESET;
    ev.dir     = SB_DIR_NA;
    ev.phase   = SB_PHASE_OBSERVED;
    ev.layout  = SB_LAYOUT_NONE;
    ev.tstamp  = $realtime;
    seq_counter++;
    ev.seq_num = seq_counter;
    ev_ap.write(ev);
  endfunction

  task run_phase(uvm_phase phase);
    logic r;
    // Assume reset is asserted at power-on, so we emit DEASSERTED (not a
    // spurious ASSERTED) at the first release.
    prev_reset = 1'b1;
    forever begin
      @(vif.mon_cb);
      r = vif.mon_cb.reset;
      if ((r === 1'b1) && (prev_reset !== 1'b1)) emit(SB_EVT_RESET_ASSERTED);
      if ((r !== 1'b1) && (prev_reset === 1'b1)) emit(SB_EVT_RESET_DEASSERTED);
      prev_reset = r;
    end
  endtask

endclass

`endif
