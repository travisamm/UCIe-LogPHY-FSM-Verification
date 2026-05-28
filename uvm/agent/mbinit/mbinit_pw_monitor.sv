`ifndef MBINIT_PW_MONITOR_SV
`define MBINIT_PW_MONITOR_SV

// ---------------------------------------------------------------------------
// mbinit_pw_monitor  (Pass 4)
// ---------------------------------------------------------------------------
// Passive observer of mb_pattern_writer_if. Emits MB_EVT_PATTERN_WRITER on:
//   * new req (req_valid 0->1, or change of req_patternType while valid):
//       svc_kind = MB_SVC_REQ, phase = OFFERED if req_ready low else ACCEPTED.
//       pattern_type evidence carries the requested type.
//   * resp_complete 0->1: svc_kind = MB_SVC_DONE.
// Suppressed while reset is high. src = MB_SRC_PATTERN_WRITER, dir = NA.
// ---------------------------------------------------------------------------
class mbinit_pw_monitor extends uvm_monitor;
  `uvm_component_utils(mbinit_pw_monitor)

  virtual mb_pattern_writer_if vif;
  uvm_analysis_port #(mbinit_event) ev_ap;

  protected int unsigned seq_counter;
  protected logic        prev_valid, prev_complete;
  protected logic [1:0]  prev_ptype;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ev_ap = new("ev_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mb_pattern_writer_if)::get(this, "", "mbinit_pw_vif", vif))
      `uvm_fatal("NO_VIF", {"mbinit_pw_vif must be set for: ", get_full_name()})
  endfunction

  protected function void reset_state();
    prev_valid    = 1'b0;
    prev_complete = 1'b0;
    prev_ptype    = 2'h0;
  endfunction

  protected function void emit(mbinit_evt_svc_e sk,
                               mbinit_evt_phase_e ph,
                               logic [1:0] ptype);
    mbinit_event ev;
    ev             = mbinit_event::type_id::create("ev");
    ev.kind        = MB_EVT_PATTERN_WRITER;
    ev.src         = MB_SRC_PATTERN_WRITER;
    ev.dir         = MB_DIR_NA;
    ev.phase       = ph;
    ev.svc_kind    = sk;
    ev.layout      = MB_LAYOUT_NONE;
    ev.pattern_type= ptype;
    ev.tstamp      = $realtime;
    seq_counter++;
    ev.seq_num     = seq_counter;
    ev_ap.write(ev);
  endfunction

  task run_phase(uvm_phase phase);
    logic       v, rdy, cmp;
    logic [1:0] pt;
    bit         new_req;
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
      cmp = vif.mon_cb.resp_complete;

      new_req = (v === 1'b1) && ((prev_valid !== 1'b1) || (pt !== prev_ptype));
      if (new_req)
        emit(MB_SVC_REQ, (rdy === 1'b1) ? MB_PHASE_ACCEPTED : MB_PHASE_OFFERED, pt);
      if ((cmp === 1'b1) && (prev_complete !== 1'b1))
        emit(MB_SVC_DONE, MB_PHASE_OBSERVED, pt);

      prev_valid    = v;
      prev_ptype    = pt;
      prev_complete = cmp;
    end
  endtask

endclass

`endif
