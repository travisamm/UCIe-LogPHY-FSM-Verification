`ifndef MBINIT_LANE_MONITOR_BASE_SV
`define MBINIT_LANE_MONITOR_BASE_SV

// ---------------------------------------------------------------------------
// mbinit_lane_monitor_base  (Pass 4)
// ---------------------------------------------------------------------------
// Shared, vif-agnostic logic for the requester and responder sideband lane
// monitors. The two lanes use distinct interface types (mb_req_if / mb_rsp_if)
// but the signal-to-event mapping is identical, so the derived monitor only
// samples its own clocking block each cycle and hands the sampled
// (valid, ready, data) to process_tx() / process_rx() here. All event state
// and emission lives in this base.
//
// Event model per lane:
//   TX (DUT -> partner)
//     Decoded message events with OFFERED / ACCEPTED lifecycle:
//       - OFFERED  : tx_valid asserted while tx_ready low (under back-pressure)
//       - ACCEPTED : tx_valid && tx_ready (the beat is taken)
//     An OFFERED beat and its later ACCEPTED beat share a lifecycle_id.
//     Under MBINIT today tx_ready is auto-stub (= tx_valid), so almost every
//     beat is observed as ACCEPTED with no prior OFFERED - this is expected.
//   RX (partner -> DUT)
//     One OBSERVED event per new valid+data (the TB-driven stimulus).
//
// Undecodable-but-valid words become MB_EVT_UNKNOWN with the raw word kept.
// Unlike SBINIT there is no clock-pattern phase to model on MBINIT lanes.
// This base is abstract: it is never created by the factory.
// ---------------------------------------------------------------------------
virtual class mbinit_lane_monitor_base extends uvm_monitor;

  uvm_analysis_port #(mbinit_event) ev_ap;

  // Set by the derived monitor in build_phase.
  mbinit_evt_src_e src;

  // Bookkeeping counters (per-monitor; lifecycle_id is namespaced by `src`).
  protected int unsigned seq_counter;
  protected int unsigned lc_counter;

  // TX edge / lifecycle state.
  protected logic         tx_prev_valid;
  protected logic [127:0] tx_prev_data;
  protected bit           tx_offer_pending;
  protected int unsigned  tx_offer_lc;
  protected logic [127:0] tx_offer_data;

  // RX edge state.
  protected logic         rx_prev_valid;
  protected logic [127:0] rx_prev_data;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ev_ap = new("ev_ap", this);
  endfunction

  // Reset all per-stream history (reset hygiene: drop partial observations).
  protected function void reset_state();
    tx_prev_valid    = 1'b0;
    tx_prev_data     = 128'h0;
    tx_offer_pending = 1'b0;
    tx_offer_lc      = 0;
    tx_offer_data    = 128'h0;
    rx_prev_valid    = 1'b0;
    rx_prev_data     = 128'h0;
  endfunction

  protected function int unsigned next_seq();
    seq_counter++;
    return seq_counter;
  endfunction

  protected function int unsigned next_lc();
    lc_counter++;
    return lc_counter;
  endfunction

  // Stamp the contextual fields the decoder cannot know.
  protected function void fill_ctx(mbinit_event ev, mbinit_evt_dir_e dir);
    ev.src     = src;
    ev.dir     = dir;
    ev.tstamp  = $realtime;
    ev.seq_num = next_seq();
  endfunction

  // -------- TX processing (one cycle's worth of sampled signals) -----------
  protected function void process_tx(logic v, logic r, logic [127:0] d);
    bit           new_msg;
    mbinit_event  ev;

    new_msg = (v === 1'b1) && ((tx_prev_valid !== 1'b1) || (d !== tx_prev_data));

    if (new_msg) begin
      ev = mbinit_decoder::decode_lane_word(d);
      fill_ctx(ev, MB_DIR_TX);
      ev.lifecycle_id = next_lc();
      if (r === 1'b1) begin
        ev.phase         = MB_PHASE_ACCEPTED;
        tx_offer_pending = 1'b0;
      end
      else begin
        ev.phase         = MB_PHASE_OFFERED;
        tx_offer_pending = 1'b1;
        tx_offer_lc      = ev.lifecycle_id;
        tx_offer_data    = d;
      end
      ev_ap.write(ev);
    end
    else if (tx_offer_pending && (v === 1'b1) && (r === 1'b1) &&
             (d === tx_offer_data)) begin
      // Previously OFFERED beat is now accepted (same payload). Re-decode so
      // the ACCEPTED event carries the decoded fields, with the shared id.
      ev = mbinit_decoder::decode_lane_word(d);
      fill_ctx(ev, MB_DIR_TX);
      ev.phase         = MB_PHASE_ACCEPTED;
      ev.lifecycle_id  = tx_offer_lc;
      tx_offer_pending = 1'b0;
      ev_ap.write(ev);
    end

    tx_prev_valid = v;
    tx_prev_data  = d;
  endfunction

  // -------- RX processing (partner -> DUT, TB-driven stimulus) -------------
  protected function void process_rx(logic v, logic [127:0] d);
    bit          new_msg;
    mbinit_event ev;

    new_msg = (v === 1'b1) && ((rx_prev_valid !== 1'b1) || (d !== rx_prev_data));
    if (new_msg) begin
      ev = mbinit_decoder::decode_lane_word(d);
      fill_ctx(ev, MB_DIR_RX);
      ev.phase = MB_PHASE_OBSERVED;
      ev_ap.write(ev);
    end

    rx_prev_valid = v;
    rx_prev_data  = d;
  endfunction

endclass

`endif
