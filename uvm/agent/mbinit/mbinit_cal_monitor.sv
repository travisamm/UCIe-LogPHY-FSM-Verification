`ifndef MBINIT_CAL_MONITOR_SV
`define MBINIT_CAL_MONITOR_SV

// ---------------------------------------------------------------------------
// mbinit_cal_monitor  (Pass 4)
// ---------------------------------------------------------------------------
// Passive observer of mb_cal_if. Emits MB_EVT_CAL on:
//   * cal_start 0 -> 1   (svc_kind = MB_SVC_START)
//   * cal_done  0 -> 1   (svc_kind = MB_SVC_DONE)
// Suppressed while reset is high. src = MB_SRC_CAL, dir = NA, phase = OBSERVED.
// ---------------------------------------------------------------------------
class mbinit_cal_monitor extends uvm_monitor;
  `uvm_component_utils(mbinit_cal_monitor)

  virtual mb_cal_if vif;
  uvm_analysis_port #(mbinit_event) ev_ap;

  protected int unsigned seq_counter;
  protected logic        prev_start, prev_done;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ev_ap = new("ev_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mb_cal_if)::get(this, "", "mbinit_cal_vif", vif))
      `uvm_fatal("NO_VIF", {"mbinit_cal_vif must be set for: ", get_full_name()})
  endfunction

  protected function void reset_state();
    prev_start = 1'b0;
    prev_done  = 1'b0;
  endfunction

  protected function void emit(mbinit_evt_svc_e sk);
    mbinit_event ev;
    ev          = mbinit_event::type_id::create("ev");
    ev.kind     = MB_EVT_CAL;
    ev.src      = MB_SRC_CAL;
    ev.dir      = MB_DIR_NA;
    ev.phase    = MB_PHASE_OBSERVED;
    ev.svc_kind = sk;
    ev.layout   = MB_LAYOUT_NONE;
    ev.tstamp   = $realtime;
    seq_counter++;
    ev.seq_num  = seq_counter;
    ev_ap.write(ev);
  endfunction

  task run_phase(uvm_phase phase);
    logic s, d;
    reset_state();
    forever begin
      @(vif.mon_cb);
      if (vif.reset === 1'b1) begin
        reset_state();
        continue;
      end
      s = vif.mon_cb.cal_start;
      d = vif.mon_cb.cal_done;
      if ((s === 1'b1) && (prev_start !== 1'b1)) emit(MB_SVC_START);
      if ((d === 1'b1) && (prev_done  !== 1'b1)) emit(MB_SVC_DONE);
      prev_start = s;
      prev_done  = d;
    end
  endtask

endclass

`endif
