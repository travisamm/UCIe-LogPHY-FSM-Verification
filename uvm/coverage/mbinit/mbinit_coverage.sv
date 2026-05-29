`ifndef MBINIT_COVERAGE_SV
`define MBINIT_COVERAGE_SV

// ===========================================================================
// mbinit_coverage  (Pass 5: event-driven)
// ---------------------------------------------------------------------------
// uvm_subscriber on the single MBINIT event stream. Maintains the same rolling
// "effective context" as the scoreboard (current state, negotiated phase) so
// crosses sample meaningfully:
//
//   * STATE / NEG_PARAMS events update the rolling context FIRST, then the
//     relevant coverpoint group is sampled.
//   * State coverage is split into:
//       - cp_state_event     : sampled on MB_EVT_STATE (state-transition cov)
//       - cp_state_at_msg    : sampled on MB_EVT_SB_MSG using effective state
//       - cp_state_at_pattern: sampled on PW/PR request using effective state
//     so msg-kind x state and pattern-type x state crosses are valid (a single
//     covergroup sample cannot meaningfully cross a state coverpoint gated on
//     STATE with a msg coverpoint gated on SB_MSG).
//
// Per-event chatter is silenced; one summary line in report_phase.
// ===========================================================================

class mbinit_coverage extends uvm_subscriber #(mbinit_event);
  `uvm_component_utils(mbinit_coverage)

  // Rolling effective context.
  protected logic [2:0] cur_state;
  protected bit         state_seen;

  // Sample staging (covergroups read these member values).
  mbinit_evt_kind_e   s_kind;
  mbinit_evt_src_e    s_src;
  mbinit_evt_dir_e    s_dir;
  mbinit_evt_phase_e  s_phase;
  mbinit_evt_svc_e    s_svc;
  mbinit_msg_kind_e   s_msg_kind;
  mbinit_role_e       s_role;
  logic [2:0]         s_state;       // for cp_state_event
  logic [2:0]         s_ctx_state;   // effective state for the dependent crosses
  logic [1:0]         s_pattern_type;

  int unsigned ev_count;

  // ---- generic per-event covergroup (every event) ----
  covergroup mbinit_evt_cg;
    option.per_instance = 1;
    option.name = "mbinit_evt_cg";

    cp_kind: coverpoint s_kind;
    cp_src:  coverpoint s_src;
    cp_dir:  coverpoint s_dir;
    cp_phase:coverpoint s_phase;
    cp_svc:  coverpoint s_svc;

    cx_kind_src: cross cp_kind, cp_src;
  endgroup

  // ---- sideband-message covergroup (sampled only on MB_EVT_SB_MSG) ----
  covergroup mbinit_msg_cg;
    option.per_instance = 1;
    option.name = "mbinit_msg_cg";

    cp_msg_kind: coverpoint s_msg_kind {
      ignore_bins none = {MB_MSG_NONE};
    }
    cp_role: coverpoint s_role {
      bins req  = {MB_ROLE_REQ};
      bins resp = {MB_ROLE_RESP};
      ignore_bins none = {MB_ROLE_NONE};
    }
    cp_state_at_msg: coverpoint s_ctx_state {
      bins PARAM      = {0};
      bins CAL        = {1};
      bins REPAIRCLK  = {2};
      bins REPAIRVAL  = {3};
      bins REVERSALMB = {4};
      bins REPAIRMB   = {5};
      bins TOMBTRAIN  = {6};
    }
    cx_msg_at_state: cross cp_msg_kind, cp_state_at_msg;
  endgroup

  // ---- pattern-request covergroup (sampled on PW/PR SVC_REQ) ----
  covergroup mbinit_pattern_cg;
    option.per_instance = 1;
    option.name = "mbinit_pattern_cg";

    cp_pattern_type: coverpoint s_pattern_type {
      bins clkrepair = {0};
      bins valtrain  = {1};
      bins perlaneid = {2};
      ignore_bins na = {3};
    }
    cp_state_at_pattern: coverpoint s_ctx_state {
      bins REPAIRCLK  = {2};
      bins REPAIRVAL  = {3};
      bins REVERSALMB = {4};
      bins REPAIRMB   = {5};
      bins other      = default;
    }
    cx_pattern_at_state: cross cp_pattern_type, cp_state_at_pattern;
  endgroup

  // ---- state-transition covergroup (sampled on MB_EVT_STATE) ----
  covergroup mbinit_state_cg;
    option.per_instance = 1;
    option.name = "mbinit_state_cg";

    cp_state_event: coverpoint s_state {
      bins PARAM      = {0};
      bins CAL        = {1};
      bins REPAIRCLK  = {2};
      bins REPAIRVAL  = {3};
      bins REVERSALMB = {4};
      bins REPAIRMB   = {5};
      bins TOMBTRAIN  = {6};
    }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    mbinit_evt_cg     = new();
    mbinit_msg_cg     = new();
    mbinit_pattern_cg = new();
    mbinit_state_cg   = new();
  endfunction

  // uvm_subscriber provides analysis_export -> write().
  virtual function void write(mbinit_event t);
    if (t == null) return;
    ev_count++;

    // ---- rolling context update FIRST ----
    if (t.kind == MB_EVT_STATE) begin
      cur_state  = t.state;
      state_seen = 1;
    end

    // ---- generic coverage (every event) ----
    s_kind  = t.kind;
    s_src   = t.src;
    s_dir   = t.dir;
    s_phase = t.phase;
    s_svc   = t.svc_kind;
    mbinit_evt_cg.sample();

    // ---- kind-specific coverage with effective context ----
    s_ctx_state = state_seen ? cur_state : 3'h0;

    case (t.kind)
      MB_EVT_STATE: begin
        s_state = t.state;
        mbinit_state_cg.sample();
      end
      MB_EVT_SB_MSG: begin
        s_msg_kind = t.msg_kind;
        s_role     = t.role;
        mbinit_msg_cg.sample();
      end
      MB_EVT_PATTERN_WRITER, MB_EVT_PATTERN_READER: begin
        if (t.svc_kind == MB_SVC_REQ) begin
          s_pattern_type = t.pattern_type;
          mbinit_pattern_cg.sample();
        end
      end
      default: ;
    endcase
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("MB_COV", $sformatf(
      "MBINIT coverage: %0d events sampled; evt_cg=%.1f%% msg_cg=%.1f%% pattern_cg=%.1f%% state_cg=%.1f%%",
      ev_count,
      mbinit_evt_cg.get_inst_coverage(),
      mbinit_msg_cg.get_inst_coverage(),
      mbinit_pattern_cg.get_inst_coverage(),
      mbinit_state_cg.get_inst_coverage()), UVM_LOW)
  endfunction

endclass
`endif
