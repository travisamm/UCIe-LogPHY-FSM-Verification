`ifndef SBINIT_COVERAGE_SV
`define SBINIT_COVERAGE_SV

// ---------------------------------------------------------------------------
// sbinit_coverage
// ---------------------------------------------------------------------------
// Functional coverage over the common sbinit_event stream. Coverpoints follow
// the event model: what kind of event, from which source/direction, in which
// handshake lifecycle phase, and which decode layout. The kind x dir cross
// captures "which protocol messages appeared in which direction", and the
// kind x phase cross captures offered-vs-accepted behavior (incl. the
// offered-under-back-pressure case the back-pressure tests exercise).
// ---------------------------------------------------------------------------
class sbinit_coverage extends uvm_subscriber #(sbinit_event);
  `uvm_component_utils(sbinit_coverage)

  sbinit_event ev_h;  // sampled handle (covergroup reads current event)

  covergroup sbinit_cg;
    option.per_instance = 1;
    option.name = "sbinit_cg";

    cp_kind: coverpoint ev_h.kind {
      bins clk_pattern   = {SB_EVT_CLK_PATTERN};
      bins clk_stop      = {SB_EVT_CLK_PATTERN_STOP};
      bins out_of_reset  = {SB_EVT_OUT_OF_RESET};
      bins done_req      = {SB_EVT_DONE_REQ};
      bins done_resp     = {SB_EVT_DONE_RESP};
      bins mode_func     = {SB_EVT_MODE_FUNCTIONAL};
      bins fsm_done      = {SB_EVT_FSM_DONE};
      bins fsm_error     = {SB_EVT_FSM_ERROR};
      bins unknown       = {SB_EVT_UNKNOWN};
    }

    cp_src: coverpoint ev_h.src {
      bins req_lane = {SB_SRC_REQ_LANE};
      bins rsp_lane = {SB_SRC_RSP_LANE};
      bins ctrl     = {SB_SRC_CTRL};
    }

    cp_dir: coverpoint ev_h.dir {
      bins tx = {SB_DIR_TX};
      bins rx = {SB_DIR_RX};
      bins na = {SB_DIR_NA};
    }

    cp_phase: coverpoint ev_h.phase {
      bins observed = {SB_PHASE_OBSERVED};
      bins offered  = {SB_PHASE_OFFERED};   // valid asserted under back-pressure
      bins accepted = {SB_PHASE_ACCEPTED};
    }

    cp_layout: coverpoint ev_h.layout {
      bins none    = {SB_LAYOUT_NONE};
      bins compare = {SB_LAYOUT_COMPARE};
      bins create  = {SB_LAYOUT_CREATE};
    }

    // Which messages appear in which direction.
    cx_kind_dir: cross cp_kind, cp_dir;

    // Offered-vs-accepted behavior per message kind (offered-under-back-pressure
    // is the interesting corner).
    cx_kind_phase: cross cp_kind, cp_phase;
  endgroup : sbinit_cg

  function new(string name, uvm_component parent);
    super.new(name, parent);
    sbinit_cg = new();
  endfunction

  function void write(sbinit_event t);
    ev_h = t;
    sbinit_cg.sample();
    `uvm_info("COVERAGE", "sample", UVM_DEBUG)
  endfunction

  function void report_phase(uvm_phase phase);
    real cov;
    cov = sbinit_cg.get_inst_coverage();
    `uvm_info("COVERAGE",
              $sformatf("SBINIT functional coverage: %0.1f%%", cov),
              UVM_LOW)
  endfunction

endclass

`endif
