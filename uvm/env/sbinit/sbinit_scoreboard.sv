`ifndef SBINIT_SCOREBOARD_SV
`define SBINIT_SCOREBOARD_SV

// ---------------------------------------------------------------------------
// sbinit_scoreboard
// ---------------------------------------------------------------------------
// Consumes the single common sbinit_event stream produced by all SBINIT event
// producers (requester lane, responder lane, FSM-control monitor), tracks which
// protocol requirements were witnessed, and prints one human-readable summary
// at end-of-test. Per-event chatter sits at UVM_HIGH so UVM_LOW logs read like
// a result, not a trace.
//
// What moved OUT of the scoreboard (vs the snapshot era):
//   * Cycle-level ready/valid payload-stability is now owned by the bound SVA
//     layer (sbinit_payload_stability_sva); the scoreboard no longer inspects
//     raw per-cycle data. It keeps only the *semantic* back-pressure check:
//     the DUT offered a beat under back-pressure and that beat was eventually
//     accepted (handshake liveness), which holds even on the buggy RTL.
//
// Malformed-activity policy: an UNKNOWN event is a hard failure UNLESS it is an
// OFFERED beat (tx_valid while tx_ready low). An OFFERED-UNKNOWN is exactly the
// known RTL back-pressure bug (data forced to 0 while valid held) and is owned
// by the SVA for tests that opt in; other tests legitimately back-pressure a
// lane (e.g. the collapse test) without asserting payload stability, so they
// must not fail on it. cfg.allow_unknown_events relaxes even the hard case.
// ---------------------------------------------------------------------------

class sbinit_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(sbinit_scoreboard)

  uvm_analysis_export   #(sbinit_event) ev_export;
  uvm_tlm_analysis_fifo #(sbinit_event) ev_fifo;

  sbinit_env_cfg cfg;

  // -------- requirement names (human-readable) ---------------------------
  static const string REQ_NAME_CLK_PATTERN        = "DUT transmits 64-UI clock pattern";
  static const string REQ_NAME_RX_SAMPLING        = "Partner clock pattern sampled by DUT";
  static const string REQ_NAME_STOP_ON_DETECT     = "DUT stops transmitting clock pattern after detection";
  static const string REQ_NAME_TIMEOUT_TRAINERROR = "FSM timeout to TRAINERROR when no pattern detected";
  static const string REQ_NAME_MODE_TRANSITION    = "Sideband mode transitions to functional";
  static const string REQ_NAME_OUT_OF_RESET       = "DUT emits SBINIT Out-of-Reset message";
  static const string REQ_NAME_DONE_HANDSHAKE     = "SBINIT done req/resp handshake completes before exit";
  static const string REQ_NAME_IGNORE_EARLY       = "DUT ignores early SBINIT done req";
  static const string REQ_NAME_COLLAPSE_REQS      = "DUT collapses multiple SBINIT done reqs into one resp";
  static const string REQ_NAME_FSM_DONE           = "fsmCtrl_done asserts at end of SBINIT";
  static const string REQ_NAME_FSM_ERROR          = "fsmCtrl_error asserts on the error path";
  static const string REQ_NAME_REQ_BP_LIVENESS    = "Requester TX beat offered under back-pressure was accepted";
  static const string REQ_NAME_RSP_BP_LIVENESS    = "Responder TX beat offered under back-pressure was accepted";
  static const string REQ_NAME_NO_MALFORMED       = "No malformed (non-back-pressure) lane activity";

  // -------- witnesses ----------------------------------------------------
  bit saw_clock_pattern;       // CLK_PATTERN on req TX
  bit saw_rx_clock_pattern;    // CLK_PATTERN on req RX (partner)
  bit sb_02_verified;
  bit sb_03_verified;
  bit sb_05_verified;
  bit sb_06_verified;
  bit saw_done_req_tx;         // DONE_REQ on req TX (DUT requester)
  bit saw_done_resp_rx;        // DONE_RESP on req RX (partner)
  bit sb_07_verified;
  bit sb_08_verified;
  bit sb_09_verified;
  bit saw_sbinit_done;         // FSM_DONE
  bit fsm_error_raised;        // FSM_ERROR
  bit tb_sent_out_of_reset;    // OUT_OF_RESET on req RX (TB drove it)
  bit tb_sent_early_done_req;  // DONE_REQ on rsp RX before out-of-reset
  bit dut_sent_early_done_resp;
  int unsigned sb_09_done_req_count;
  int unsigned sb_09_done_resp_count;

  // Semantic back-pressure liveness (offer under back-pressure -> accepted).
  bit saw_req_tx_offer_under_bp;
  bit saw_req_tx_accept;
  bit saw_rsp_tx_offer_under_bp;
  bit saw_rsp_tx_accept;

  // Malformed-activity tracking.
  bit saw_unknown_hard;     // UNKNOWN that is NOT an offered-under-bp beat
  bit saw_unknown_offered;  // UNKNOWN offered under back-pressure (SVA owns it)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ev_export = new("ev_export", this);
    ev_fifo   = new("ev_fifo",   this);

    if (!uvm_config_db#(sbinit_env_cfg)::get(this, "", "cfg", cfg)) begin
      `uvm_info("SBINIT_SB", "No cfg in config_db; using default expectations", UVM_MEDIUM)
      cfg = sbinit_env_cfg::type_id::create("cfg");
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    ev_export.connect(ev_fifo.analysis_export);
  endfunction

  task run_phase(uvm_phase phase);
    sbinit_event ev;
    saw_clock_pattern         = 0;
    saw_rx_clock_pattern      = 0;
    sb_02_verified            = 0;
    sb_03_verified            = 0;
    sb_05_verified            = 0;
    sb_06_verified            = 0;
    saw_done_req_tx           = 0;
    saw_done_resp_rx          = 0;
    sb_07_verified            = 0;
    sb_08_verified            = 0;
    sb_09_verified            = 0;
    saw_sbinit_done           = 0;
    fsm_error_raised          = 0;
    tb_sent_out_of_reset      = 0;
    tb_sent_early_done_req    = 0;
    dut_sent_early_done_resp  = 0;
    sb_09_done_req_count      = 0;
    sb_09_done_resp_count     = 0;
    saw_req_tx_offer_under_bp = 0;
    saw_req_tx_accept         = 0;
    saw_rsp_tx_offer_under_bp = 0;
    saw_rsp_tx_accept         = 0;
    saw_unknown_hard          = 0;
    saw_unknown_offered       = 0;

    forever begin
      ev_fifo.get(ev);
      process_event(ev);
    end
  endtask

  // -------------------------------------------------------------------
  // Per-event processing. Chatter sits at UVM_HIGH.
  // -------------------------------------------------------------------
  function void process_event(sbinit_event ev);
    // Malformed-activity policy (any source/direction).
    if (ev.kind == SB_EVT_UNKNOWN) begin
      if (ev.phase == SB_PHASE_OFFERED) begin
        // Offered under back-pressure: the known RTL stability bug; owned by
        // the SVA layer for tests that opt in. Not a hard failure here.
        saw_unknown_offered = 1;
      end
      else begin
        saw_unknown_hard = 1;
        if (!cfg.allow_unknown_events)
          `uvm_error("SBINIT_SB",
                     {"Malformed lane activity (valid word did not decode): ",
                      ev.convert2string()})
      end
    end

    case (ev.src)
      SB_SRC_CTRL:     process_ctrl(ev);
      SB_SRC_REQ_LANE: process_req_lane(ev);
      SB_SRC_RSP_LANE: process_rsp_lane(ev);
      default: ;
    endcase
  endfunction

  function void process_ctrl(sbinit_event ev);
    case (ev.kind)
      SB_EVT_MODE_FUNCTIONAL: begin
        // Mode functional implies SB-05; combined with partner pattern, SB-02.
        if (saw_clock_pattern && !sb_05_verified) begin
          `uvm_info("SBINIT_SB", {"witnessed: ", REQ_NAME_MODE_TRANSITION}, UVM_HIGH)
          sb_05_verified = 1;
        end
        if (saw_clock_pattern && saw_rx_clock_pattern && !sb_02_verified) begin
          `uvm_info("SBINIT_SB", {"witnessed: ", REQ_NAME_RX_SAMPLING}, UVM_HIGH)
          sb_02_verified = 1;
        end
      end
      SB_EVT_FSM_DONE: begin
        if (!saw_sbinit_done) begin
          if (saw_done_req_tx && saw_done_resp_rx) begin
            `uvm_info("SBINIT_SB", {"witnessed: ", REQ_NAME_DONE_HANDSHAKE}, UVM_HIGH)
            sb_07_verified = 1;
          end
          if (tb_sent_early_done_req && !dut_sent_early_done_resp) begin
            `uvm_info("SBINIT_SB", {"witnessed: ", REQ_NAME_IGNORE_EARLY}, UVM_HIGH)
            sb_08_verified = 1;
          end
          saw_sbinit_done = 1;
        end
      end
      SB_EVT_FSM_ERROR: begin
        if (!fsm_error_raised) begin
          `uvm_info("SBINIT_SB", "fsmCtrl_error asserted", UVM_MEDIUM)
          fsm_error_raised = 1;
        end
      end
      default: ;
    endcase
  endfunction

  function void process_req_lane(sbinit_event ev);
    if (ev.dir == SB_DIR_TX) begin
      // SB-01 clock-pattern emission.
      if (ev.kind == SB_EVT_CLK_PATTERN && !saw_clock_pattern) begin
        `uvm_info("SBINIT_SB", {"witnessed: ", REQ_NAME_CLK_PATTERN}, UVM_HIGH)
        saw_clock_pattern = 1;
      end
      // SB-03 stop-on-detect: pattern stopped after both TX and RX patterns.
      if (ev.kind == SB_EVT_CLK_PATTERN_STOP &&
          saw_clock_pattern && saw_rx_clock_pattern && !sb_03_verified) begin
        `uvm_info("SBINIT_SB", {"witnessed: ", REQ_NAME_STOP_ON_DETECT}, UVM_HIGH)
        sb_03_verified = 1;
      end
      // SB-06 Out-of-Reset emission.
      if (ev.kind == SB_EVT_OUT_OF_RESET && !sb_06_verified) begin
        `uvm_info("SBINIT_SB", {"witnessed: ", REQ_NAME_OUT_OF_RESET}, UVM_HIGH)
        sb_06_verified = 1;
      end
      // Done req emitted by the DUT requester.
      if (ev.kind == SB_EVT_DONE_REQ) saw_done_req_tx = 1;
      // Back-pressure liveness (offer under bp, then accept).
      if (ev.phase == SB_PHASE_OFFERED)  saw_req_tx_offer_under_bp = 1;
      if (ev.phase == SB_PHASE_ACCEPTED) saw_req_tx_accept         = 1;
    end
    else if (ev.dir == SB_DIR_RX) begin
      if (ev.kind == SB_EVT_CLK_PATTERN)  saw_rx_clock_pattern = 1;
      if (ev.kind == SB_EVT_OUT_OF_RESET) tb_sent_out_of_reset = 1;
      if (ev.kind == SB_EVT_DONE_RESP)    saw_done_resp_rx     = 1;
    end
  endfunction

  function void process_rsp_lane(sbinit_event ev);
    if (ev.dir == SB_DIR_RX) begin
      // Early done req (before TB sent Out-of-Reset on the requester lane).
      if (ev.kind == SB_EVT_DONE_REQ && !tb_sent_out_of_reset)
        tb_sent_early_done_req = 1;
      // SB-09: count done-req bursts after Out-of-Reset (one event per burst).
      if (ev.kind == SB_EVT_DONE_REQ && tb_sent_out_of_reset)
        sb_09_done_req_count++;
    end
    else if (ev.dir == SB_DIR_TX) begin
      // DUT must not answer an early done req before Out-of-Reset.
      if (ev.kind == SB_EVT_DONE_RESP &&
          tb_sent_early_done_req && !tb_sent_out_of_reset) begin
        `uvm_error("SBINIT_SB",
                   {"FAILED requirement \"", REQ_NAME_IGNORE_EARLY,
                    "\": DUT sent done resp prematurely"})
        dut_sent_early_done_resp = 1;
      end
      // SB-09: count accepted done resps once multiple reqs have been seen.
      if (ev.kind == SB_EVT_DONE_RESP && ev.phase == SB_PHASE_ACCEPTED &&
          sb_09_done_req_count > 1)
        sb_09_done_resp_count++;
      // Back-pressure liveness.
      if (ev.phase == SB_PHASE_OFFERED)  saw_rsp_tx_offer_under_bp = 1;
      if (ev.phase == SB_PHASE_ACCEPTED) saw_rsp_tx_accept         = 1;
    end
  endfunction

  // -------------------------------------------------------------------
  // End-of-test reporting
  // -------------------------------------------------------------------
  typedef enum {STAT_PASS, STAT_FAIL, STAT_SKIP, STAT_NA} status_e;

  function string status_str(status_e s);
    case (s)
      STAT_PASS: return "PASS";
      STAT_FAIL: return "FAIL";
      STAT_SKIP: return "skip";
      STAT_NA:   return "n/a ";
      default:   return "??? ";
    endcase
  endfunction

  // Emit one summary row; return 1 only when it counts as FAIL.
  function bit report_row(string name, bit expected, bit witnessed,
                          bit not_applicable = 0);
    status_e s;
    if (not_applicable)        s = STAT_NA;
    else if (!expected)        s = STAT_SKIP;
    else if (witnessed)        s = STAT_PASS;
    else                       s = STAT_FAIL;
    `uvm_info("SBINIT_SB",
              $sformatf("  [ %s ] %s", status_str(s), name),
              UVM_LOW)
    return (s == STAT_FAIL);
  endfunction

  function void check_phase(uvm_phase phase);
    int unsigned errs_before;
    int unsigned fail_count;
    bit          overall_fail;

    errs_before = uvm_report_server::get_server().get_severity_count(UVM_ERROR);

    // Derive SB-09 from the collected counters before printing.
    if (sb_09_done_req_count > 1) begin
      if (!saw_sbinit_done) begin
        `uvm_error("SBINIT_SB",
                   {"FAILED requirement \"", REQ_NAME_COLLAPSE_REQS,
                    "\": FSM did not complete after multiple done reqs"})
      end else if (sb_09_done_resp_count == 1) begin
        sb_09_verified = 1;
      end else begin
        `uvm_error("SBINIT_SB",
                   $sformatf("FAILED requirement \"%s\": saw %0d done reqs and %0d done resps",
                             REQ_NAME_COLLAPSE_REQS,
                             sb_09_done_req_count, sb_09_done_resp_count))
      end
    end

    // -------- summary table --------
    `uvm_info("SBINIT_SB",
              "===================================================================",
              UVM_LOW)
    `uvm_info("SBINIT_SB", "SBINIT scoreboard summary", UVM_LOW)
    `uvm_info("SBINIT_SB",
              "===================================================================",
              UVM_LOW)

    fail_count = 0;
    fail_count += report_row(REQ_NAME_CLK_PATTERN,
                             cfg.expect_sb01_clock_pattern,   saw_clock_pattern);
    fail_count += report_row(REQ_NAME_RX_SAMPLING,
                             cfg.expect_sb02_rx_sampling,     sb_02_verified);
    fail_count += report_row(REQ_NAME_STOP_ON_DETECT,
                             cfg.expect_sb03_stop_on_detect,  sb_03_verified);
    // SB-04 timeout is not observable in this RTL (fsmCtrl_error tied 0).
    fail_count += report_row(REQ_NAME_TIMEOUT_TRAINERROR,
                             cfg.expect_fsm_error,            fsm_error_raised,
                             .not_applicable(!cfg.expect_fsm_error));
    fail_count += report_row(REQ_NAME_MODE_TRANSITION,
                             cfg.expect_sb05_mode_transition, sb_05_verified);
    fail_count += report_row(REQ_NAME_OUT_OF_RESET,
                             cfg.expect_sb06_out_of_reset,    sb_06_verified);
    fail_count += report_row(REQ_NAME_DONE_HANDSHAKE,
                             cfg.expect_sb07_done_handshake,  sb_07_verified);
    fail_count += report_row(REQ_NAME_IGNORE_EARLY,
                             cfg.expect_sb08_ignore_early,    sb_08_verified);
    fail_count += report_row(REQ_NAME_COLLAPSE_REQS,
                             cfg.expect_sb09_collapse_reqs,   sb_09_verified);
    fail_count += report_row(REQ_NAME_FSM_DONE,
                             cfg.expect_fsm_done,             saw_sbinit_done);
    // Semantic back-pressure liveness is opt-in per lane (same cfg flag that
    // gates the SVA payload-stability checker). Cycle-level payload stability
    // itself is owned by the SVA layer, not this row.
    fail_count += report_row(REQ_NAME_REQ_BP_LIVENESS,
                             cfg.expect_req_tx_data_stable,
                             saw_req_tx_offer_under_bp && saw_req_tx_accept);
    fail_count += report_row(REQ_NAME_RSP_BP_LIVENESS,
                             cfg.expect_rsp_tx_data_stable,
                             saw_rsp_tx_offer_under_bp && saw_rsp_tx_accept);
    // Malformed activity (excluding offered-under-back-pressure beats).
    fail_count += report_row(REQ_NAME_NO_MALFORMED,
                             !cfg.allow_unknown_events,       !saw_unknown_hard);

    `uvm_info("SBINIT_SB",
              "-------------------------------------------------------------------",
              UVM_LOW)

    // Fire uvm_errors for FAILed expected requirements so the regress harness
    // detects them. (SB-09/SB-08 and malformed-activity already fire inline.)
    if (cfg.expect_sb01_clock_pattern && !saw_clock_pattern)
      `uvm_error("SBINIT_SB",
                 {"FAILED requirement \"", REQ_NAME_CLK_PATTERN, "\": never witnessed"})
    if (cfg.expect_sb02_rx_sampling && !sb_02_verified)
      `uvm_error("SBINIT_SB",
                 {"FAILED requirement \"", REQ_NAME_RX_SAMPLING,
                  "\": mode never went functional after incoming pattern"})
    if (cfg.expect_sb03_stop_on_detect && !sb_03_verified)
      `uvm_error("SBINIT_SB",
                 {"FAILED requirement \"", REQ_NAME_STOP_ON_DETECT,
                  "\": DUT kept transmitting after detection"})
    if (cfg.expect_sb05_mode_transition && !sb_05_verified)
      `uvm_error("SBINIT_SB",
                 {"FAILED requirement \"", REQ_NAME_MODE_TRANSITION,
                  "\": sbRxTxMode never transitioned to functional"})
    if (cfg.expect_sb06_out_of_reset && !sb_06_verified)
      `uvm_error("SBINIT_SB",
                 {"FAILED requirement \"", REQ_NAME_OUT_OF_RESET,
                  "\": DUT never sent Out-of-Reset message"})
    if (cfg.expect_sb07_done_handshake && !sb_07_verified)
      `uvm_error("SBINIT_SB",
                 {"FAILED requirement \"", REQ_NAME_DONE_HANDSHAKE,
                  "\": done req/resp handshake not completed before exit"})
    if (cfg.expect_sb08_ignore_early && !sb_08_verified)
      `uvm_error("SBINIT_SB",
                 {"FAILED requirement \"", REQ_NAME_IGNORE_EARLY,
                  "\": DUT did not ignore the early done req"})
    if (cfg.expect_sb09_collapse_reqs && !sb_09_verified)
      `uvm_error("SBINIT_SB",
                 {"FAILED requirement \"", REQ_NAME_COLLAPSE_REQS,
                  "\": DUT did not collapse multiple done reqs into one resp"})
    if (cfg.expect_fsm_done && !saw_sbinit_done)
      `uvm_error("SBINIT_SB",
                 {"FAILED requirement \"", REQ_NAME_FSM_DONE,
                  "\": fsmCtrl_done never asserted"})
    if (cfg.expect_fsm_error && !fsm_error_raised)
      `uvm_error("SBINIT_SB",
                 {"FAILED requirement \"", REQ_NAME_FSM_ERROR,
                  "\": fsmCtrl_error never asserted"})
    if (!cfg.expect_fsm_error && fsm_error_raised)
      `uvm_error("SBINIT_SB", "Unexpected fsmCtrl_error on a success-path test")
    if (cfg.expect_req_tx_data_stable &&
        !(saw_req_tx_offer_under_bp && saw_req_tx_accept))
      `uvm_error("SBINIT_SB",
                 {"FAILED requirement \"", REQ_NAME_REQ_BP_LIVENESS,
                  "\": never saw an offered-under-back-pressure beat accepted"})
    if (cfg.expect_rsp_tx_data_stable &&
        !(saw_rsp_tx_offer_under_bp && saw_rsp_tx_accept))
      `uvm_error("SBINIT_SB",
                 {"FAILED requirement \"", REQ_NAME_RSP_BP_LIVENESS,
                  "\": never saw an offered-under-back-pressure beat accepted"})

    overall_fail = (uvm_report_server::get_server().get_severity_count(UVM_ERROR) > errs_before) ||
                   (fail_count > 0);

    if (overall_fail)
      `uvm_info("SBINIT_SB",
                $sformatf("Overall: FAIL  (%0d requirement(s) marked FAIL)", fail_count),
                UVM_LOW)
    else
      `uvm_info("SBINIT_SB",
                "Overall: PASS  (every expected requirement was witnessed)",
                UVM_LOW)
    `uvm_info("SBINIT_SB",
              "===================================================================",
              UVM_LOW)
  endfunction

endclass

`endif
