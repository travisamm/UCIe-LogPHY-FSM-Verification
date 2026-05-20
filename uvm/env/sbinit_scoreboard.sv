`ifndef SBINIT_SCOREBOARD_SV
`define SBINIT_SCOREBOARD_SV

// ---------------------------------------------------------------------------
// sbinit_scoreboard
// ---------------------------------------------------------------------------
// Watches the requester and responder analysis streams from the two SBINIT
// agents, tracks which protocol requirements were witnessed, and produces a
// single human-readable summary at end-of-test. Per-event chatter is kept at
// UVM_HIGH or higher so that UVM_LOW logs read like a test result, not a
// trace.
//
// Each requirement carries an internal short code (sb_01..09) for code
// clarity, but the test log only ever uses the descriptive name.
// ---------------------------------------------------------------------------

class sbinit_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(sbinit_scoreboard)

  uvm_analysis_export  #(sbinit_req_transaction) req_export;
  uvm_analysis_export  #(sbinit_rsp_transaction) rsp_export;
  uvm_tlm_analysis_fifo #(sbinit_req_transaction) req_fifo;
  uvm_tlm_analysis_fifo #(sbinit_rsp_transaction) rsp_fifo;

  sbinit_env_cfg cfg;

  // -------- requirement names (human-readable) ---------------------------
  // Used in both per-event chatter and the end-of-test summary.
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

  // -------- witnesses ----------------------------------------------------
  bit saw_clock_pattern;
  bit saw_rx_clock_pattern;
  bit saw_sbinit_done;
  bit sb_02_verified;
  bit sb_03_verified;
  bit sb_05_verified;
  bit sb_06_verified;
  bit saw_sbinit_done_req;
  bit saw_sbinit_done_resp;
  bit sb_07_verified;
  bit sb_08_verified;
  bit sb_09_verified;
  bit tb_sent_out_of_reset;
  bit tb_sent_early_done_req;
  bit dut_sent_early_done_resp;
  bit fsm_error_raised;
  bit prev_rsp_done_req_active;
  int unsigned sb_09_done_req_count;
  int unsigned sb_09_done_resp_count;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    req_export = new("req_export", this);
    rsp_export = new("rsp_export", this);
    req_fifo   = new("req_fifo",   this);
    rsp_fifo   = new("rsp_fifo",   this);

    if (!uvm_config_db#(sbinit_env_cfg)::get(this, "", "cfg", cfg)) begin
      `uvm_info("SBINIT_SB", "No cfg in config_db; using default expectations", UVM_MEDIUM)
      cfg = sbinit_env_cfg::type_id::create("cfg");
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    req_export.connect(req_fifo.analysis_export);
    rsp_export.connect(rsp_fifo.analysis_export);
  endfunction

  task run_phase(uvm_phase phase);
    saw_clock_pattern        = 0;
    saw_rx_clock_pattern     = 0;
    saw_sbinit_done          = 0;
    sb_02_verified           = 0;
    sb_03_verified           = 0;
    sb_05_verified           = 0;
    sb_06_verified           = 0;
    saw_sbinit_done_req      = 0;
    saw_sbinit_done_resp     = 0;
    sb_07_verified           = 0;
    sb_08_verified           = 0;
    sb_09_verified           = 0;
    tb_sent_out_of_reset     = 0;
    tb_sent_early_done_req   = 0;
    dut_sent_early_done_resp = 0;
    fsm_error_raised         = 0;
    prev_rsp_done_req_active = 0;
    sb_09_done_req_count     = 0;
    sb_09_done_resp_count    = 0;

    fork
      forever begin
        sbinit_req_transaction req_tx;
        req_fifo.get(req_tx);
        process_req(req_tx);
      end
      forever begin
        sbinit_rsp_transaction rsp_tx;
        rsp_fifo.get(rsp_tx);
        process_rsp(rsp_tx);
      end
    join_none
  endtask

  // -------------------------------------------------------------------
  // Per-event processing
  //
  // All per-event chatter sits at UVM_HIGH or higher: those edges are
  // useful when debugging a failure but useless when a test passes.
  // -------------------------------------------------------------------
  task process_req(sbinit_req_transaction tx);
    // Clock-pattern emission on requester TX.
    if (tx.tx_valid && (tx.tx_data == SBINIT_CLK_PATTERN_A  ||
                        tx.tx_data == SBINIT_CLK_PATTERN_A5 ||
                        tx.tx_data == SBINIT_CLK_PATTERN_5A ||
                        tx.tx_data == SBINIT_CLK_PATTERN_5)) begin
      if (!saw_clock_pattern) begin
        `uvm_info("SBINIT_SB",
                  {"witnessed: ", REQ_NAME_CLK_PATTERN},
                  UVM_HIGH)
        saw_clock_pattern = 1;
      end
    end else if (saw_clock_pattern && !sb_03_verified) begin
      if (saw_rx_clock_pattern) begin
        `uvm_info("SBINIT_SB",
                  {"witnessed: ", REQ_NAME_STOP_ON_DETECT},
                  UVM_HIGH)
        sb_03_verified = 1;
      end
    end

    // Partner clock-pattern arrival on requester RX.
    if (tx.rx_valid && tx.rx_data == SBINIT_CLK_PATTERN_5)
      saw_rx_clock_pattern = 1;

    // Mode transition: implies both RX sampling and pattern→functional.
    if (saw_clock_pattern && tx.sbRxTxMode == 1) begin
      if (saw_rx_clock_pattern && !sb_02_verified) begin
        `uvm_info("SBINIT_SB",
                  {"witnessed: ", REQ_NAME_RX_SAMPLING},
                  UVM_HIGH)
        sb_02_verified = 1;
      end
      if (!sb_05_verified) begin
        `uvm_info("SBINIT_SB",
                  {"witnessed: ", REQ_NAME_MODE_TRANSITION},
                  UVM_HIGH)
        sb_05_verified = 1;
      end
    end

    // TB drove its own Out-of-Reset on requester RX.
    if (tx.rx_valid &&
        is_sbinit_msg(tx.rx_data, SBINIT_MC_OUT_OF_RESET, SBINIT_SC_OOR))
      tb_sent_out_of_reset = 1;

    // DUT emits Out-of-Reset on requester TX.
    if (tx.tx_valid &&
        is_sbinit_msg(tx.tx_data, SBINIT_MC_OUT_OF_RESET, SBINIT_SC_OOR)) begin
      if (!sb_06_verified) begin
        `uvm_info("SBINIT_SB",
                  {"witnessed: ", REQ_NAME_OUT_OF_RESET},
                  UVM_HIGH)
        sb_06_verified = 1;
      end
    end

    // Done req emitted on requester TX.
    if (tx.tx_valid &&
        is_sbinit_msg(tx.tx_data, SBINIT_MC_DONE_REQ, SBINIT_SC_DONE))
      saw_sbinit_done_req = 1;

    // Done resp received on requester RX.
    if (tx.rx_valid &&
        is_sbinit_msg(tx.rx_data, SBINIT_MC_DONE_RESP, SBINIT_SC_DONE))
      saw_sbinit_done_resp = 1;

    // FSM error edge (currently tied 0 inside the RTL).
    if (tx.fsm_error && !fsm_error_raised) begin
      `uvm_info("SBINIT_SB",
                "fsmCtrl_error asserted",
                UVM_MEDIUM)
      fsm_error_raised = 1;
    end

    // FSM done edge — finalize handshake / early-req checks.
    if (tx.fsm_done && !saw_sbinit_done) begin
      if (saw_sbinit_done_req && saw_sbinit_done_resp) begin
        `uvm_info("SBINIT_SB",
                  {"witnessed: ", REQ_NAME_DONE_HANDSHAKE},
                  UVM_HIGH)
        sb_07_verified = 1;
      end
      if (tb_sent_early_done_req && !dut_sent_early_done_resp) begin
        `uvm_info("SBINIT_SB",
                  {"witnessed: ", REQ_NAME_IGNORE_EARLY},
                  UVM_HIGH)
        sb_08_verified = 1;
      end
      saw_sbinit_done = 1;
    end
  endtask

  task process_rsp(sbinit_rsp_transaction tx);
    // Early {done req} on responder RX (before TB sent Out-of-Reset).
    if (tx.rx_valid &&
        is_sbinit_msg(tx.rx_data, SBINIT_MC_DONE_REQ, SBINIT_SC_DONE) &&
        !tb_sent_out_of_reset)
      tb_sent_early_done_req = 1;

    // Edge-detect {done req} bursts on responder RX after Out-of-Reset.
    if (tb_sent_out_of_reset &&
        tx.rx_valid &&
        is_sbinit_msg(tx.rx_data, SBINIT_MC_DONE_REQ, SBINIT_SC_DONE) &&
        !prev_rsp_done_req_active) begin
      sb_09_done_req_count++;
    end
    prev_rsp_done_req_active = tb_sent_out_of_reset &&
                               tx.rx_valid &&
                               is_sbinit_msg(tx.rx_data, SBINIT_MC_DONE_REQ, SBINIT_SC_DONE);

    // DUT must not respond to an early done req before Out-of-Reset.
    if (tx.tx_valid &&
        is_sbinit_msg(tx.tx_data, SBINIT_MC_DONE_RESP, SBINIT_SC_DONE) &&
        tb_sent_early_done_req && !tb_sent_out_of_reset) begin
      `uvm_error("SBINIT_SB",
                 {"FAILED requirement \"", REQ_NAME_IGNORE_EARLY,
                  "\": DUT sent done resp prematurely"})
      dut_sent_early_done_resp = 1;
    end

    // After multiple done reqs were sent, count accepted done resps.
    if (sb_09_done_req_count > 1 &&
        tx.tx_valid && tx.tx_ready &&
        is_sbinit_msg(tx.tx_data, SBINIT_MC_DONE_RESP, SBINIT_SC_DONE)) begin
      sb_09_done_resp_count++;
    end
  endtask

  // -------------------------------------------------------------------
  // End-of-test reporting
  // -------------------------------------------------------------------
  // Status tag for the summary table.
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

  // Emit one row of the summary table and return whether it counts as a
  // FAIL. PASS/SKIP/N/A all return 0; only FAIL returns 1.
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

    // Derive SB-09 verification from collected counters before printing.
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
    `uvm_info("SBINIT_SB",
              "SBINIT scoreboard summary",
              UVM_LOW)
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

    `uvm_info("SBINIT_SB",
              "-------------------------------------------------------------------",
              UVM_LOW)

    // Fire any uvm_errors for FAILed expected requirements so the regress
    // harness picks them up. (The SB-09/SB-08 paths already fire their
    // own uvm_errors when they fail; these cover the simpler witnesses.)
    if (cfg.expect_sb01_clock_pattern && !saw_clock_pattern)
      `uvm_error("SBINIT_SB",
                 {"FAILED requirement \"", REQ_NAME_CLK_PATTERN,
                  "\": never witnessed"})
    if (cfg.expect_sb02_rx_sampling && !sb_02_verified)
      `uvm_error("SBINIT_SB",
                 {"FAILED requirement \"", REQ_NAME_RX_SAMPLING,
                  "\": sbRxTxMode never went to 1 after incoming pattern"})
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
      `uvm_error("SBINIT_SB",
                 "Unexpected fsmCtrl_error on a success-path test")

    overall_fail = (uvm_report_server::get_server().get_severity_count(UVM_ERROR) > errs_before) ||
                   (fail_count > 0);

    if (overall_fail) begin
      `uvm_info("SBINIT_SB",
                $sformatf("Overall: FAIL  (%0d requirement(s) marked FAIL)", fail_count),
                UVM_LOW)
    end else begin
      `uvm_info("SBINIT_SB",
                "Overall: PASS  (every expected requirement was witnessed)",
                UVM_LOW)
    end
    `uvm_info("SBINIT_SB",
              "===================================================================",
              UVM_LOW)
  endfunction

endclass

`endif
