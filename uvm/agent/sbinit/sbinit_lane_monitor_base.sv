`ifndef SBINIT_LANE_MONITOR_BASE_SV
`define SBINIT_LANE_MONITOR_BASE_SV

// ---------------------------------------------------------------------------
// sbinit_lane_monitor_base
// ---------------------------------------------------------------------------
// Shared, vif-agnostic logic for the requester and responder lane monitors.
// The two lanes use distinct interface types (sb_req_if / sb_rsp_if) but the
// signal-to-event mapping is identical, so the derived monitor only samples its
// own clocking block each cycle and hands the sampled (valid, ready, data)
// to process_tx() / process_rx() here. All event state and emission lives in
// this base, so the protocol-decode contract has a single implementation.
//
// Event model produced per lane:
//   TX (DUT -> partner)
//     * CLK_PATTERN        (OBSERVED) on each new clock-pattern word
//     * CLK_PATTERN_STOP   (OBSERVED) when the lane stops emitting the pattern
//     * message kinds emitted with OFFERED / ACCEPTED lifecycle:
//         - OFFERED  : tx_valid asserted while tx_ready low (under back-pressure)
//         - ACCEPTED : tx_valid && tx_ready (the beat is taken)
//       An OFFERED beat and its later ACCEPTED beat share a lifecycle_id.
//   RX (partner -> DUT)
//     * one OBSERVED event per new message (the TB-driven stimulus)
//
// Undecodable-but-valid words become SB_EVT_UNKNOWN with the raw word retained.
// This base is abstract: it is never created by the factory.
// ---------------------------------------------------------------------------
virtual class sbinit_lane_monitor_base extends uvm_monitor;

  uvm_analysis_port #(sbinit_event) ev_ap;

  // Set by the derived monitor in build_phase.
  sbinit_evt_src_e src;

  // Bookkeeping counters.
  protected int unsigned seq_counter;
  protected int unsigned lc_counter;

  // TX edge / lifecycle state.
  protected logic         tx_prev_valid;
  protected logic [127:0] tx_prev_data;
  protected bit           tx_in_clk;
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
    tx_in_clk        = 1'b0;
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
  protected function void fill_ctx(sbinit_event ev, sbinit_evt_dir_e dir);
    ev.src     = src;
    ev.dir     = dir;
    ev.tstamp  = $realtime;
    ev.seq_num = next_seq();
  endfunction

  // Build a non-decoded event (clock-pattern stop, etc.).
  protected function sbinit_event make_evt(sbinit_evt_kind_e   k,
                                           sbinit_evt_dir_e    dir,
                                           sbinit_evt_phase_e  ph,
                                           logic [127:0]       raw);
    sbinit_event ev;
    ev        = sbinit_event::type_id::create("ev");
    ev.kind   = k;
    ev.layout = SB_LAYOUT_NONE;
    ev.phase  = ph;
    ev.raw    = raw;
    fill_ctx(ev, dir);
    return ev;
  endfunction

  // -------- TX processing (one cycle's worth of sampled signals) ----------
  protected function void process_tx(logic v, logic r, logic [127:0] d);
    bit          new_msg;
    sbinit_event ev;

    // Clock-pattern stop: was emitting a pattern, no longer is (valid dropped
    // or the word is no longer a clock pattern). Switching between two clock
    // patterns does not count as a stop.
    if (tx_in_clk && ((v !== 1'b1) || !sbinit_decoder::is_clock_pattern(d))) begin
      ev_ap.write(make_evt(SB_EVT_CLK_PATTERN_STOP, SB_DIR_TX,
                           SB_PHASE_OBSERVED, tx_prev_data));
      tx_in_clk = 1'b0;
    end

    new_msg = (v === 1'b1) && ((tx_prev_valid !== 1'b1) || (d !== tx_prev_data));

    if (new_msg) begin
      ev = sbinit_decoder::decode_lane_word(d);
      fill_ctx(ev, SB_DIR_TX);

      if (ev.kind == SB_EVT_CLK_PATTERN) begin
        // Raw-mode clock pattern: a point-in-time observation, no handshake.
        ev.phase         = SB_PHASE_OBSERVED;
        tx_in_clk        = 1'b1;
        tx_offer_pending = 1'b0;
      end
      else begin
        // Message beat: track the offer/accept lifecycle.
        ev.lifecycle_id = next_lc();
        if (r === 1'b1) begin
          ev.phase         = SB_PHASE_ACCEPTED;
          tx_offer_pending = 1'b0;
        end
        else begin
          ev.phase         = SB_PHASE_OFFERED;
          tx_offer_pending = 1'b1;
          tx_offer_lc      = ev.lifecycle_id;
          tx_offer_data    = d;
        end
      end
      ev_ap.write(ev);
    end
    else if (tx_offer_pending && (v === 1'b1) && (r === 1'b1) &&
             (d === tx_offer_data)) begin
      // A previously OFFERED beat is now accepted (same payload). Re-decode so
      // the ACCEPTED event carries the decoded fields, with the shared id.
      ev = sbinit_decoder::decode_lane_word(d);
      fill_ctx(ev, SB_DIR_TX);
      ev.phase        = SB_PHASE_ACCEPTED;
      ev.lifecycle_id = tx_offer_lc;
      tx_offer_pending = 1'b0;
      ev_ap.write(ev);
    end

    tx_prev_valid = v;
    tx_prev_data  = d;
  endfunction

  // -------- RX processing (partner -> DUT, TB-driven stimulus) -------------
  protected function void process_rx(logic v, logic [127:0] d);
    bit          new_msg;
    sbinit_event ev;

    new_msg = (v === 1'b1) && ((rx_prev_valid !== 1'b1) || (d !== rx_prev_data));
    if (new_msg) begin
      ev = sbinit_decoder::decode_lane_word(d);
      fill_ctx(ev, SB_DIR_RX);
      ev.phase = SB_PHASE_OBSERVED;
      ev_ap.write(ev);
    end

    rx_prev_valid = v;
    rx_prev_data  = d;
  endfunction

endclass

`endif
