`ifndef SBINIT_CTRL_MONITOR_SV
`define SBINIT_CTRL_MONITOR_SV

// ---------------------------------------------------------------------------
// sbinit_ctrl_monitor
// ---------------------------------------------------------------------------
// Dedicated passive monitor for the FSM control bus (sb_ctrl_if). It turns the
// control-signal edges into protocol events on the common sbinit_event stream:
//   * SB_EVT_MODE_FUNCTIONAL  on sbRxTxMode 0 -> 1
//   * SB_EVT_FSM_DONE         on fsmCtrl_done rising edge
//   * SB_EVT_FSM_ERROR        on fsmCtrl_error rising edge
// All control events use src = SB_SRC_CTRL, dir = SB_DIR_NA, phase = OBSERVED.
//
// This is instantiated directly by the env (the control bus has no driver of
// its own - fsmCtrl_start is driven by the requester rx driver).
// ---------------------------------------------------------------------------
class sbinit_ctrl_monitor extends uvm_monitor;
  `uvm_component_utils(sbinit_ctrl_monitor)

  virtual sb_ctrl_if vif;
  uvm_analysis_port #(sbinit_event) ev_ap;

  protected int unsigned seq_counter;
  protected logic        prev_mode;
  protected logic        prev_done;
  protected logic        prev_error;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ev_ap = new("ev_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual sb_ctrl_if)::get(this, "", "sbinit_ctrl_vif", vif))
      `uvm_fatal("NO_VIF", {"sbinit_ctrl_vif must be set for: ", get_full_name()})
  endfunction

  protected function void reset_state();
    prev_mode  = 1'b0;
    prev_done  = 1'b0;
    prev_error = 1'b0;
  endfunction

  protected function void emit(sbinit_evt_kind_e k);
    sbinit_event ev;
    ev         = sbinit_event::type_id::create("ev");
    ev.kind    = k;
    ev.src     = SB_SRC_CTRL;
    ev.dir     = SB_DIR_NA;
    ev.phase   = SB_PHASE_OBSERVED;
    ev.layout  = SB_LAYOUT_NONE;
    ev.tstamp  = $realtime;
    seq_counter++;
    ev.seq_num = seq_counter;
    ev_ap.write(ev);
  endfunction

  task run_phase(uvm_phase phase);
    logic mode, done, err;
    reset_state();
    forever begin
      @(vif.mon_cb);
      if (vif.reset === 1'b1) begin
        reset_state();
        continue;
      end
      mode = vif.mon_cb.sbRxTxMode;
      done = vif.mon_cb.fsmCtrl_done;
      err  = vif.mon_cb.fsmCtrl_error;

      if ((mode === 1'b1) && (prev_mode !== 1'b1)) emit(SB_EVT_MODE_FUNCTIONAL);
      if ((done === 1'b1) && (prev_done !== 1'b1)) emit(SB_EVT_FSM_DONE);
      if ((err  === 1'b1) && (prev_error !== 1'b1)) emit(SB_EVT_FSM_ERROR);

      prev_mode  = mode;
      prev_done  = done;
      prev_error = err;
    end
  endtask

endclass

`endif
