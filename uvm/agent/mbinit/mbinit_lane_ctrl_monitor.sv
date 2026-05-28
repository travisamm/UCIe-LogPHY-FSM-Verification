`ifndef MBINIT_LANE_CTRL_MONITOR_SV
`define MBINIT_LANE_CTRL_MONITOR_SV

// ---------------------------------------------------------------------------
// mbinit_lane_ctrl_monitor  (Pass 4)
// ---------------------------------------------------------------------------
// Passive observer of mbLaneCtrlIo on mb_lane_ctrl_if. Emits MB_EVT_LANE_CTRL
// with a snapshot of all eight En fields (XC-05 evidence) on:
//   * the first post-reset sample,
//   * any subsequent change of any En field.
//
// Suppressed while reset is high. All events use src=MB_SRC_LANE_CTRL,
// dir=NA, phase=OBSERVED, svc_kind=NONE.
// ---------------------------------------------------------------------------
class mbinit_lane_ctrl_monitor extends uvm_monitor;
  `uvm_component_utils(mbinit_lane_ctrl_monitor)

  virtual mb_lane_ctrl_if vif;
  uvm_analysis_port #(mbinit_event) ev_ap;

  protected int unsigned seq_counter;
  protected bit          init_done;
  protected logic [15:0] p_tx_de, p_rx_de;
  protected logic        p_tx_ce, p_tx_ve, p_tx_te;
  protected logic        p_rx_ce, p_rx_ve, p_rx_te;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ev_ap = new("ev_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mb_lane_ctrl_if)::get(this, "", "mbinit_lane_ctrl_vif", vif))
      `uvm_fatal("NO_VIF", {"mbinit_lane_ctrl_vif must be set for: ", get_full_name()})
  endfunction

  protected function void reset_state();
    init_done = 1'b0;
    p_tx_de = 16'h0; p_rx_de = 16'h0;
    p_tx_ce = 1'b0; p_tx_ve = 1'b0; p_tx_te = 1'b0;
    p_rx_ce = 1'b0; p_rx_ve = 1'b0; p_rx_te = 1'b0;
  endfunction

  task run_phase(uvm_phase phase);
    mbinit_event ev;
    logic [15:0] tx_de, rx_de;
    logic        tx_ce, tx_ve, tx_te, rx_ce, rx_ve, rx_te;
    bit          changed;
    reset_state();
    forever begin
      @(vif.mon_cb);
      if (vif.reset === 1'b1) begin
        reset_state();
        continue;
      end
      tx_de = vif.mon_cb.tx_data_en;
      tx_ce = vif.mon_cb.tx_clk_en;
      tx_ve = vif.mon_cb.tx_valid_en;
      tx_te = vif.mon_cb.tx_track_en;
      rx_de = vif.mon_cb.rx_data_en;
      rx_ce = vif.mon_cb.rx_clk_en;
      rx_ve = vif.mon_cb.rx_valid_en;
      rx_te = vif.mon_cb.rx_track_en;

      changed = !init_done ||
                (tx_de !== p_tx_de) || (rx_de !== p_rx_de) ||
                (tx_ce !== p_tx_ce) || (tx_ve !== p_tx_ve) || (tx_te !== p_tx_te) ||
                (rx_ce !== p_rx_ce) || (rx_ve !== p_rx_ve) || (rx_te !== p_rx_te);

      if (changed) begin
        ev          = mbinit_event::type_id::create("ev");
        ev.kind     = MB_EVT_LANE_CTRL;
        ev.src      = MB_SRC_LANE_CTRL;
        ev.dir      = MB_DIR_NA;
        ev.phase    = MB_PHASE_OBSERVED;
        ev.svc_kind = MB_SVC_NONE;
        ev.layout   = MB_LAYOUT_NONE;
        ev.lc_tx_data_en  = tx_de;
        ev.lc_tx_clk_en   = tx_ce;
        ev.lc_tx_valid_en = tx_ve;
        ev.lc_tx_track_en = tx_te;
        ev.lc_rx_data_en  = rx_de;
        ev.lc_rx_clk_en   = rx_ce;
        ev.lc_rx_valid_en = rx_ve;
        ev.lc_rx_track_en = rx_te;
        ev.tstamp   = $realtime;
        seq_counter++;
        ev.seq_num  = seq_counter;
        ev_ap.write(ev);

        init_done = 1'b1;
        p_tx_de = tx_de; p_rx_de = rx_de;
        p_tx_ce = tx_ce; p_tx_ve = tx_ve; p_tx_te = tx_te;
        p_rx_ce = rx_ce; p_rx_ve = rx_ve; p_rx_te = rx_te;
      end
    end
  endtask

endclass

`endif
