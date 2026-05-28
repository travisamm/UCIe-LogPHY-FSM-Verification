`ifndef MBINIT_CTRL_MONITOR_SV
`define MBINIT_CTRL_MONITOR_SV

// ---------------------------------------------------------------------------
// mbinit_ctrl_monitor  (Pass 4)
// ---------------------------------------------------------------------------
// Dedicated passive monitor for the FSM-control / PHY-status bus (mb_ctrl_if).
// Turns control-bus edges into events on the common mbinit_event stream:
//   * MB_EVT_STATE           on first post-reset state sample and every
//                            currentState change (src=MB_SRC_CTRL, evidence=state)
//   * MB_EVT_NEG_PARAMS      on negotiatedPhySettings_valid 0->1 OR change of
//                            negotiated rate/mode/phase while valid is high
//                            (src=MB_SRC_PARAMS, evidence=neg_*)
//   * MB_EVT_INTEROP_FAIL    on interoperableParamsNotFound rising edge
//   * MB_EVT_TXWIDTH_CHANGED on io_txWidthChanged rising edge
//   * MB_EVT_FSM_DONE        on fsmCtrl_done rising edge
//   * MB_EVT_FSM_ERROR       on fsmCtrl_error rising edge
//
// Suppressed while reset is high. All events use phase=OBSERVED, dir=NA,
// svc_kind=NONE.
// ---------------------------------------------------------------------------
class mbinit_ctrl_monitor extends uvm_monitor;
  `uvm_component_utils(mbinit_ctrl_monitor)

  virtual mb_ctrl_if vif;
  uvm_analysis_port #(mbinit_event) ev_ap;

  protected int unsigned seq_counter;
  protected bit          state_init;
  protected logic [2:0]  prev_state;
  protected logic        prev_neg_valid;
  protected logic [3:0]  prev_neg_rate;
  protected logic        prev_neg_mode;
  protected logic        prev_neg_phase;
  protected logic        prev_interop;
  protected logic        prev_txwc;
  protected logic        prev_done;
  protected logic        prev_error;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ev_ap = new("ev_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mb_ctrl_if)::get(this, "", "mbinit_ctrl_vif", vif))
      `uvm_fatal("NO_VIF", {"mbinit_ctrl_vif must be set for: ", get_full_name()})
  endfunction

  protected function void reset_state();
    state_init     = 1'b0;
    prev_state     = 3'h0;
    prev_neg_valid = 1'b0;
    prev_neg_rate  = 4'h0;
    prev_neg_mode  = 1'b0;
    prev_neg_phase = 1'b0;
    prev_interop   = 1'b0;
    prev_txwc      = 1'b0;
    prev_done      = 1'b0;
    prev_error     = 1'b0;
  endfunction

  protected function int unsigned next_seq();
    seq_counter++;
    return seq_counter;
  endfunction

  // Build a control-bus event (carries the state evidence by default).
  protected function mbinit_event mk(mbinit_evt_kind_e k, mbinit_evt_src_e s);
    mbinit_event ev;
    ev          = mbinit_event::type_id::create("ev");
    ev.kind     = k;
    ev.src      = s;
    ev.dir      = MB_DIR_NA;
    ev.phase    = MB_PHASE_OBSERVED;
    ev.svc_kind = MB_SVC_NONE;
    ev.layout   = MB_LAYOUT_NONE;
    ev.state    = prev_state;
    ev.tstamp   = $realtime;
    ev.seq_num  = next_seq();
    return ev;
  endfunction

  task run_phase(uvm_phase phase);
    mbinit_event ev;
    logic [2:0]  st;
    logic        nv, nm, np, ipf, twc, dn, er;
    logic [3:0]  nr;
    reset_state();
    forever begin
      @(vif.mon_cb);
      if (vif.reset === 1'b1) begin
        reset_state();
        continue;
      end

      st  = vif.mon_cb.currentState;
      nv  = vif.mon_cb.negotiatedPhySettings_valid;
      nr  = vif.mon_cb.negotiatedPhySettings_maxDataRate;
      nm  = vif.mon_cb.negotiatedPhySettings_clockMode;
      np  = vif.mon_cb.negotiatedPhySettings_clockPhase;
      ipf = vif.mon_cb.interoperableParamsNotFound;
      twc = vif.mon_cb.txWidthChanged;
      dn  = vif.mon_cb.fsmCtrl_done;
      er  = vif.mon_cb.fsmCtrl_error;

      // STATE: first post-reset sample and every subsequent change.
      if (!state_init || (st !== prev_state)) begin
        prev_state = st;
        state_init = 1'b1;
        ev = mk(MB_EVT_STATE, MB_SRC_CTRL);
        ev.state = st;
        ev_ap.write(ev);
      end

      // NEG_PARAMS: rising-valid OR change while valid high.
      if ((nv === 1'b1) &&
          ((prev_neg_valid !== 1'b1) ||
           (nr !== prev_neg_rate) || (nm !== prev_neg_mode) || (np !== prev_neg_phase))) begin
        ev = mk(MB_EVT_NEG_PARAMS, MB_SRC_PARAMS);
        ev.neg_data_rate   = nr;
        ev.neg_clock_mode  = nm;
        ev.neg_clock_phase = np;
        ev_ap.write(ev);
      end

      // Edges.
      if ((ipf === 1'b1) && (prev_interop !== 1'b1))
        ev_ap.write(mk(MB_EVT_INTEROP_FAIL,    MB_SRC_CTRL));
      if ((twc === 1'b1) && (prev_txwc !== 1'b1))
        ev_ap.write(mk(MB_EVT_TXWIDTH_CHANGED, MB_SRC_CTRL));
      if ((dn  === 1'b1) && (prev_done !== 1'b1))
        ev_ap.write(mk(MB_EVT_FSM_DONE,        MB_SRC_CTRL));
      if ((er  === 1'b1) && (prev_error !== 1'b1))
        ev_ap.write(mk(MB_EVT_FSM_ERROR,       MB_SRC_CTRL));

      prev_neg_valid = nv;
      prev_neg_rate  = nr;
      prev_neg_mode  = nm;
      prev_neg_phase = np;
      prev_interop   = ipf;
      prev_txwc      = twc;
      prev_done      = dn;
      prev_error     = er;
    end
  endtask

endclass

`endif
