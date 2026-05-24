`ifndef SBINIT_PREDICTOR_SV
`define SBINIT_PREDICTOR_SV

// ---------------------------------------------------------------------------
// sbinit_predictor  (golden reference model)
// ---------------------------------------------------------------------------
// A self-checking spec FSM for SBINIT, grounded in UCIe 3.0 Section 4.5.3.2
// (NOT in the RTL under test). It consumes the common sbinit_event stream and
// validates that every DUT *output* event (lane TX, mode, fsmCtrl_done) is
// legal for the protocol phase implied by the *input* events (lane RX, reset)
// observed so far. It complements - does not replace - the requirement-witness
// scoreboard: the scoreboard answers "did each requirement happen?", this model
// answers "did the DUT do the right thing, in the spec-mandated order?".
//
// Two parallel models mirror the requester/responder split:
//   Requester: REQ_PATTERN -> REQ_OUT_OF_RESET -> REQ_DONE -> REQ_COMPLETE
//     - PATTERN: DUT emits the clock pattern. Partner clock pattern on RX, then
//       mode->functional, advances (spec Steps 1-4).
//     - OUT_OF_RESET: DUT emits {SBINIT Out of Reset}. Partner OoR on RX
//       advances (Steps 7-8); this is also when the responder "starts"
//       (responder start = requester out-of-reset).
//     - DONE: DUT emits {SBINIT done req}. Partner {done resp} on RX completes.
//   Responder: RSP_IDLE -> RSP_ACTIVE -> RSP_COMPLETE
//     - IDLE: responder not started; it must NOT answer a {done req} yet.
//     - ACTIVE: a {done req} on RX is answered with a {done resp} TX (Step 10).
//
// Checks (always on, every test):
//   * unexpected output: a recognized message/mode transmitted in a phase where
//     the spec does not allow it (e.g. done-req before the OoR exchange, an
//     early done-resp before the responder started, mode functional before the
//     partner pattern was detected),
//   * fsmCtrl_done causality: asserts only when both FSMs have completed
//     (Step 10),
//   * missing output: the model advanced through a phase but the DUT never even
//     attempted the required transmission.
//
// Content corruption (the known RTL ready/valid bug -> UNKNOWN/zero beats) is
// flagged ONLY on a lane whose cfg.expect_*_tx_data_stable is set, mirroring the
// stream-stability SVA opt-in. So the collapse test (which legitimately back-
// pressures the responder without asserting stability) stays clean, while the
// two stability tests fail via both the SVA and this model.
// ---------------------------------------------------------------------------

class sbinit_predictor extends uvm_scoreboard;
  `uvm_component_utils(sbinit_predictor)

  uvm_analysis_export   #(sbinit_event) ev_export;
  uvm_tlm_analysis_fifo #(sbinit_event) ev_fifo;

  sbinit_env_cfg cfg;

  typedef enum { REQ_PATTERN, REQ_OUT_OF_RESET, REQ_DONE, REQ_COMPLETE } req_phase_e;
  typedef enum { RSP_IDLE, RSP_ACTIVE, RSP_COMPLETE }                    rsp_phase_e;

  req_phase_e  req_phase;
  rsp_phase_e  rsp_phase;
  bit          partner_pattern_seen;
  bit          fsm_done_seen;
  int unsigned divergences;

  // Output-attempt tracking (an UNKNOWN beat counts as an attempt so a back-
  // pressured-but-present message is not also flagged as "missing").
  bit req_tx_attempt_oor;
  bit req_tx_attempt_done_req;
  bit rsp_tx_attempt_done_resp;

  // Sticky content-corruption flags so a back-pressure window logs one error
  // per lane, not one per cycle.
  bit req_content_flagged;
  bit rsp_content_flagged;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ev_export = new("ev_export", this);
    ev_fifo   = new("ev_fifo",   this);
    if (!uvm_config_db#(sbinit_env_cfg)::get(this, "", "cfg", cfg)) begin
      `uvm_info("SBINIT_REF", "No cfg in config_db; using default expectations", UVM_MEDIUM)
      cfg = sbinit_env_cfg::type_id::create("cfg");
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    ev_export.connect(ev_fifo.analysis_export);
  endfunction

  function void reset_model();
    req_phase                = REQ_PATTERN;
    rsp_phase                = RSP_IDLE;
    partner_pattern_seen     = 0;
    fsm_done_seen            = 0;
    req_tx_attempt_oor       = 0;
    req_tx_attempt_done_req  = 0;
    rsp_tx_attempt_done_resp = 0;
    req_content_flagged      = 0;
    rsp_content_flagged      = 0;
  endfunction

  function void flag(string msg);
    divergences++;
    `uvm_error("SBINIT_REF", {"reference-model divergence: ", msg})
  endfunction

  task run_phase(uvm_phase phase);
    sbinit_event ev;
    reset_model();
    divergences = 0;
    forever begin
      ev_fifo.get(ev);
      process_event(ev);
    end
  endtask

  function void process_event(sbinit_event ev);
    // Reset boundary segments the modeled attempt (matches the scoreboard).
    if (ev.kind == SB_EVT_RESET_ASSERTED) begin
      reset_model();
      return;
    end
    if (ev.kind == SB_EVT_RESET_DEASSERTED) return;

    case (ev.src)
      SB_SRC_REQ_LANE: proc_req(ev);
      SB_SRC_RSP_LANE: proc_rsp(ev);
      SB_SRC_CTRL:     proc_ctrl(ev);
      default: ;
    endcase
  endfunction

  // ---- requester lane --------------------------------------------------
  function void proc_req(sbinit_event ev);
    if (ev.dir == SB_DIR_RX) begin
      // Inputs from the partner advance the modeled phase.
      case (ev.kind)
        SB_EVT_CLK_PATTERN: partner_pattern_seen = 1;
        SB_EVT_OUT_OF_RESET:
          if (req_phase == REQ_OUT_OF_RESET) begin
            req_phase = REQ_DONE;
            if (rsp_phase == RSP_IDLE) rsp_phase = RSP_ACTIVE; // responder start
          end
        SB_EVT_DONE_RESP:
          if (req_phase == REQ_DONE) req_phase = REQ_COMPLETE;
        default: ; // {done req} is not expected on the requester RX
      endcase
    end
    else if (ev.dir == SB_DIR_TX) begin
      // DUT outputs are validated against the current phase.
      case (ev.kind)
        SB_EVT_CLK_PATTERN:
          if (req_phase != REQ_PATTERN)
            flag("requester transmitted a clock pattern outside the pattern phase");
        SB_EVT_OUT_OF_RESET: begin
          if (req_phase != REQ_OUT_OF_RESET)
            flag("requester transmitted {Out of Reset} outside the OUT_OF_RESET phase");
          req_tx_attempt_oor = 1;
        end
        SB_EVT_DONE_REQ: begin
          if (req_phase != REQ_DONE)
            flag("requester transmitted {done req} before the {Out of Reset} exchange completed");
          req_tx_attempt_done_req = 1;
        end
        SB_EVT_DONE_RESP:
          flag("requester lane transmitted {done resp} (a responder-only message)");
        SB_EVT_UNKNOWN: begin
          if (req_phase == REQ_OUT_OF_RESET) req_tx_attempt_oor      = 1;
          if (req_phase == REQ_DONE)         req_tx_attempt_done_req = 1;
          if (cfg.expect_req_tx_data_stable && !req_content_flagged &&
              (req_phase == REQ_OUT_OF_RESET || req_phase == REQ_DONE)) begin
            req_content_flagged = 1;
            flag("requester transmitted a corrupted/zero payload while a message was due (ready/valid data-stability bug)");
          end
        end
        default: ;
      endcase
    end
  endfunction

  // ---- responder lane --------------------------------------------------
  function void proc_rsp(sbinit_event ev);
    if (ev.dir == SB_DIR_TX) begin
      case (ev.kind)
        SB_EVT_DONE_RESP: begin
          if (rsp_phase == RSP_IDLE)
            flag("responder transmitted {done resp} before it was started (premature - before the Out-of-Reset exchange)");
          else if (rsp_phase == RSP_COMPLETE)
            flag("responder transmitted an extra {done resp} after completing");
          else
            rsp_phase = RSP_COMPLETE;
          rsp_tx_attempt_done_resp = 1;
        end
        SB_EVT_UNKNOWN:
          if (rsp_phase == RSP_ACTIVE) begin
            rsp_tx_attempt_done_resp = 1;
            if (cfg.expect_rsp_tx_data_stable && !rsp_content_flagged) begin
              rsp_content_flagged = 1;
              flag("responder transmitted a corrupted/zero payload while a {done resp} was due (ready/valid data-stability bug)");
            end
          end
        SB_EVT_CLK_PATTERN, SB_EVT_OUT_OF_RESET, SB_EVT_DONE_REQ:
          flag("responder lane transmitted an unexpected message type");
        default: ;
      endcase
    end
    // Responder RX {done req} needs no state change here; its legality is
    // enforced on the TX side (a response while RSP_IDLE is the violation).
  endfunction

  // ---- FSM control -----------------------------------------------------
  function void proc_ctrl(sbinit_event ev);
    case (ev.kind)
      SB_EVT_MODE_FUNCTIONAL: begin
        if (!partner_pattern_seen)
          flag("sideband mode went functional before the partner clock pattern was detected");
        if (req_phase == REQ_PATTERN) req_phase = REQ_OUT_OF_RESET;
      end
      SB_EVT_FSM_DONE: begin
        fsm_done_seen = 1;
        if (!(req_phase == REQ_COMPLETE && rsp_phase == RSP_COMPLETE))
          flag("fsmCtrl_done asserted before the SBINIT done handshake completed (UCIe 4.5.3.2 Step 10)");
      end
      default: ; // FSM_ERROR not modeled: SBINIT RTL ties error to 0
    endcase
  endfunction

  // ---- end-of-test: missing-output / completion liveness ----------------
  function void check_phase(uvm_phase phase);
    if ((req_phase == REQ_DONE || req_phase == REQ_COMPLETE) && !req_tx_attempt_oor)
      flag("requester reached the done phase but never transmitted {Out of Reset}");
    if (req_phase == REQ_COMPLETE && !req_tx_attempt_done_req)
      flag("requester completed but never transmitted {done req}");
    if (rsp_phase == RSP_COMPLETE && !rsp_tx_attempt_done_resp)
      flag("responder completed but never transmitted {done resp}");
    if (req_phase == REQ_COMPLETE && rsp_phase == RSP_COMPLETE && !fsm_done_seen)
      flag("SBINIT handshake completed but fsmCtrl_done never asserted");

    if (divergences == 0)
      `uvm_info("SBINIT_REF",
                $sformatf("reference model: DUT conformed to the SBINIT spec FSM (final phases req=%s rsp=%s)",
                          req_phase.name(), rsp_phase.name()),
                UVM_LOW)
    else
      `uvm_info("SBINIT_REF",
                $sformatf("reference model: %0d divergence(s) from the SBINIT spec FSM (final phases req=%s rsp=%s)",
                          divergences, req_phase.name(), rsp_phase.name()),
                UVM_LOW)
  endfunction

endclass

`endif
