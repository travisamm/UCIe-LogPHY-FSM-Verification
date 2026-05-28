`ifndef MBINIT_PR_MONITOR_SV
`define MBINIT_PR_MONITOR_SV

// ---------------------------------------------------------------------------
// mbinit_pr_monitor  (Pass 4)
// ---------------------------------------------------------------------------
// Passive observer of mb_pattern_reader_if. Emits MB_EVT_PATTERN_READER on:
//   * new req (req_valid 0->1, or change of req_patternType while valid):
//       svc_kind = MB_SVC_REQ, phase = OFFERED if req_ready low else ACCEPTED.
//   * req_done  0->1 : svc_kind = MB_SVC_DONE
//   * req_clear 0->1 : svc_kind = MB_SVC_CLEAR
//   * resp_valid 0->1: svc_kind = MB_SVC_RESULT (carries pr_per_lane + pr_aggregate)
// Suppressed while reset is high. src = MB_SRC_PATTERN_READER, dir = NA.
// ---------------------------------------------------------------------------
class mbinit_pr_monitor extends uvm_monitor;
  `uvm_component_utils(mbinit_pr_monitor)

  virtual mb_pattern_reader_if vif;
  uvm_analysis_port #(mbinit_event) ev_ap;

  protected int unsigned seq_counter;
  protected logic        prev_valid, prev_done, prev_clear, prev_resp_valid;
  protected logic [1:0]  prev_ptype;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ev_ap = new("ev_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mb_pattern_reader_if)::get(this, "", "mbinit_pr_vif", vif))
      `uvm_fatal("NO_VIF", {"mbinit_pr_vif must be set for: ", get_full_name()})
  endfunction

  protected function void reset_state();
    prev_valid      = 1'b0;
    prev_done       = 1'b0;
    prev_clear      = 1'b0;
    prev_resp_valid = 1'b0;
    prev_ptype      = 2'h0;
  endfunction

  protected function mbinit_event mk(mbinit_evt_svc_e sk, mbinit_evt_phase_e ph);
    mbinit_event ev;
    ev          = mbinit_event::type_id::create("ev");
    ev.kind     = MB_EVT_PATTERN_READER;
    ev.src      = MB_SRC_PATTERN_READER;
    ev.dir      = MB_DIR_NA;
    ev.phase    = ph;
    ev.svc_kind = sk;
    ev.layout   = MB_LAYOUT_NONE;
    ev.tstamp   = $realtime;
    seq_counter++;
    ev.seq_num  = seq_counter;
    return ev;
  endfunction

  task run_phase(uvm_phase phase);
    mbinit_event ev;
    logic        v, rdy, dn, cl, rv;
    logic [1:0]  pt;
    logic [15:0] pl;
    logic        ag;
    bit          new_req;
    reset_state();
    forever begin
      @(vif.mon_cb);
      if (vif.reset === 1'b1) begin
        reset_state();
        continue;
      end
      v   = vif.mon_cb.req_valid;
      rdy = vif.mon_cb.req_ready;
      pt  = vif.mon_cb.req_patternType;
      dn  = vif.mon_cb.req_done;
      cl  = vif.mon_cb.req_clear;
      rv  = vif.mon_cb.resp_valid;
      pl  = vif.mon_cb.resp_perLane;
      ag  = vif.mon_cb.resp_aggregate;

      new_req = (v === 1'b1) && ((prev_valid !== 1'b1) || (pt !== prev_ptype));
      if (new_req) begin
        ev = mk(MB_SVC_REQ, (rdy === 1'b1) ? MB_PHASE_ACCEPTED : MB_PHASE_OFFERED);
        ev.pattern_type = pt;
        ev_ap.write(ev);
      end
      if ((dn === 1'b1) && (prev_done !== 1'b1)) begin
        ev = mk(MB_SVC_DONE, MB_PHASE_OBSERVED);
        ev.pattern_type = pt;
        ev_ap.write(ev);
      end
      if ((cl === 1'b1) && (prev_clear !== 1'b1)) begin
        ev = mk(MB_SVC_CLEAR, MB_PHASE_OBSERVED);
        ev.pattern_type = pt;
        ev_ap.write(ev);
      end
      if ((rv === 1'b1) && (prev_resp_valid !== 1'b1)) begin
        ev = mk(MB_SVC_RESULT, MB_PHASE_OBSERVED);
        ev.pr_per_lane  = pl;
        ev.pr_aggregate = ag;
        ev_ap.write(ev);
      end

      prev_valid      = v;
      prev_ptype      = pt;
      prev_done       = dn;
      prev_clear      = cl;
      prev_resp_valid = rv;
    end
  endtask

endclass

`endif
