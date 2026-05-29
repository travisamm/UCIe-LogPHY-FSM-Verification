`ifndef MBINIT_SCOREBOARD_SV
`define MBINIT_SCOREBOARD_SV

// ===========================================================================
// mbinit_scoreboard  (Pass 5: event-driven)
// ---------------------------------------------------------------------------
// Consumes the single MBINIT event stream (mbinit_event) produced by the Pass 4
// monitors instead of the legacy mbinit_transaction snapshots. Same class name,
// same public expect_* API, and the SAME check_phase requirement errors as the
// legacy scoreboard, so test pass/fail semantics do not shift.
//
// Witnesses (MP/MC/RC/RV/LR/RM/XC-05/pattern-type/RM scenarios) are derived from
// events, qualified by SOURCE (which lane produced the event), not just by the
// decoded role:
//   * requester TX : src=MB_SRC_REQ_LANE && dir=TX && role=REQ
//   * responder TX : src=MB_SRC_RSP_LANE && dir=TX && role=RESP
//   * partner resp : src=MB_SRC_REQ_LANE && dir=RX && role=RESP (LR-01)
// Unrecognized DUT TX (MB_EVT_UNKNOWN on a TX lane) hard-errors, exactly like
// the legacy scoreboard's saw_bad_{req,rsp}_tx.
//
// Same-cycle ordering hazard: STATE / LANE_CTRL / NEG_PARAMS / service / point-
// test / sideband events can share a timestamp and arrive in either FIFO order.
// Events are processed in TIMESTAMP BUCKETS: all events at one $realtime are
// collected, then (Phase A) STATE/NEG_PARAMS/LANE_CTRL update the effective
// rolling context, then (Phase B) state-dependent checks run against that
// settled context. The final bucket is flushed (and the FIFO drained) in
// check_phase.
//
// cfg: build_phase copies mbinit_env_cfg defaults into the public expect_*
// fields; tests may still mutate env.scoreboard.expect_* afterward.
// ===========================================================================

class mbinit_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(mbinit_scoreboard)

  // MBINIT state encodings (io_currentState).
  localparam logic [2:0] MB_STATE_PARAM      = 3'd0;
  localparam logic [2:0] MB_STATE_CAL        = 3'd1;
  localparam logic [2:0] MB_STATE_REPAIRCLK  = 3'd2;
  localparam logic [2:0] MB_STATE_REPAIRVAL  = 3'd3;
  localparam logic [2:0] MB_STATE_REVERSALMB = 3'd4;
  localparam logic [2:0] MB_STATE_REPAIRMB   = 3'd5;
  localparam logic [2:0] MB_STATE_TOMBTRAIN  = 3'd6;

  // Pattern types (patternWriter/Reader).
  localparam logic [1:0] PT_CLKREPAIR = 2'h0;
  localparam logic [1:0] PT_VALTRAIN  = 2'h1;
  localparam logic [1:0] PT_PERLANEID = 2'h2;

  // ---- event ingress ----
  uvm_analysis_export   #(mbinit_event) ev_export;
  uvm_tlm_analysis_fifo #(mbinit_event) ev_fifo;

  // ====================== witnesses (names match legacy) ====================
  bit saw_req_tx;
  bit saw_rsp_tx;
  bit saw_bad_req_tx;
  bit saw_bad_rsp_tx;
  bit saw_param_req_tx;
  bit saw_param_resp_tx;
  bit mp_02_verified;
  bit mp_03_verified;
  bit mp_04_triggered;

  bit saw_state_cal;
  bit saw_state_repairclk;
  bit saw_state_repairval;
  bit saw_state_reversalmb;
  bit saw_state_repairmb;
  bit saw_state_tombtrain;

  bit saw_cal_req_tx;
  bit saw_cal_resp_tx;

  bit saw_rclk_init_req_tx;
  bit saw_rclk_init_resp_tx;
  bit saw_rclk_res_req_tx;
  bit saw_rclk_res_resp_tx;
  bit saw_rclk_done_req_tx;
  bit saw_rclk_done_resp_tx;

  bit saw_repairclk_lane_ctrl_good;
  bit saw_repairclk_pw_clkrepair;
  bit saw_repairclk_pr_clkrepair;

  bit saw_rval_init_req_tx;
  bit saw_rval_init_resp_tx;
  bit saw_rval_res_req_tx;
  bit saw_rval_res_resp_tx;
  bit saw_rval_done_req_tx;
  bit saw_rval_done_resp_tx;

  bit saw_rv01_pw_valtrain;
  bit saw_rv01_repairval_reader_on;
  bit saw_rv01_using_pw;
  bit rv01_phase_constraint_violation;

  bit saw_lr_init_req_tx;
  bit saw_lr_init_resp_tx;
  bit saw_lr_init_resp_rx;
  bit saw_lr_res_req_tx;
  bit saw_lr_res_resp_tx;
  bit saw_lr_done_req_tx;
  bit saw_lr_done_resp_tx;

  bit saw_rm_start_req_tx;
  bit saw_rm_start_resp_tx;
  bit saw_rm_end_req_tx;
  bit saw_rm_end_resp_tx;

  bit saw_fsm_done;
  bit saw_fsm_error;

  bit lane_ctrl_error;
  bit pattern_type_error;

  bit saw_lr03_pattern_reader_reversalmb;
  bit saw_apply_lane_reversal;
  bit saw_rm02_heterogeneous_pt_repairmb;
  bit saw_repairmb_txwidth_pulse;
  int unsigned repairmb_pt_results_beats;

  // ====================== expect_* (public, test-settable) ==================
  bit expect_param_messages     = 1;
  bit expect_param_common_rate  = 1;
  bit expect_param_negotiation  = 1;
  bit expect_full_mbinit        = 1;
  bit expect_mbinit_through_cal = 0;
  bit expect_mbinit_through_repairclk = 0;
  bit expect_repairclk_rc03      = 0;
  bit expect_interop_failure    = 0;
  bit expect_fsm_done           = 1;
  bit expect_fsm_error          = 0;
  bit expect_lane_ctrl_checks   = 1;
  bit expect_pattern_type_checks = 1;
  bit expect_rv01_checks         = 1;
  bit expect_lr03_pattern_reader = 1;
  bit expect_lr04_apply_lane_reversal = 0;
  bit expect_rm02_per_lane_reader = 0;
  bit expect_rm07_repairmb_unrepairable = 0;
  bit expect_rm05_post_repair_witness = 0;

  // ====================== rolling effective context =========================
  protected bit          state_seen;
  protected logic [2:0]  cur_state;
  protected bit          lc_seen;
  protected logic [15:0] lc_tx_data_en;
  protected logic        lc_tx_clk_en, lc_tx_valid_en, lc_tx_track_en;
  protected logic [15:0] lc_rx_data_en;
  protected logic        lc_rx_clk_en, lc_rx_valid_en, lc_rx_track_en;
  protected bit          cur_using_pw, cur_using_pr, cur_apply_lr, cur_local_phase;
  protected bit          neg_valid;
  protected bit          neg_phase;

  // ====================== timestamp-bucket state ============================
  protected mbinit_event bucket[$];
  protected real         bucket_t;
  protected bit          have_bucket;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    mbinit_env_cfg cfg;
    super.build_phase(phase);
    ev_export = new("ev_export", this);
    ev_fifo   = new("ev_fifo", this);

    // Pull expectation defaults from cfg (tests may still override afterward).
    if (uvm_config_db#(mbinit_env_cfg)::get(this, "", "cfg", cfg) && cfg != null) begin
      expect_param_messages           = cfg.expect_param_messages;
      expect_param_common_rate        = cfg.expect_param_common_rate;
      expect_param_negotiation        = cfg.expect_param_negotiation;
      expect_full_mbinit              = cfg.expect_full_mbinit;
      expect_mbinit_through_cal       = cfg.expect_mbinit_through_cal;
      expect_mbinit_through_repairclk = cfg.expect_mbinit_through_repairclk;
      expect_repairclk_rc03           = cfg.expect_repairclk_rc03;
      expect_interop_failure          = cfg.expect_interop_failure;
      expect_fsm_done                 = cfg.expect_fsm_done;
      expect_fsm_error                = cfg.expect_fsm_error;
      expect_lane_ctrl_checks         = cfg.expect_lane_ctrl_checks;
      expect_pattern_type_checks      = cfg.expect_pattern_type_checks;
      expect_rv01_checks              = cfg.expect_rv01_checks;
      expect_lr03_pattern_reader      = cfg.expect_lr03_pattern_reader;
      expect_lr04_apply_lane_reversal = cfg.expect_lr04_apply_lane_reversal;
      expect_rm02_per_lane_reader     = cfg.expect_rm02_per_lane_reader;
      expect_rm07_repairmb_unrepairable = cfg.expect_rm07_repairmb_unrepairable;
      expect_rm05_post_repair_witness = cfg.expect_rm05_post_repair_witness;
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    ev_export.connect(ev_fifo.analysis_export);
  endfunction

  // ====================== event consumption (bucketed) ======================
  task run_phase(uvm_phase phase);
    mbinit_event ev;
    have_bucket = 0;
    forever begin
      ev_fifo.get(ev);
      if (have_bucket && (ev.tstamp != bucket_t)) begin
        process_bucket();
        bucket.delete();
      end
      bucket.push_back(ev);
      bucket_t    = ev.tstamp;
      have_bucket = 1;
    end
  endtask

  // Drain any FIFO remainder + process the final bucket (events written in the
  // last delta of the run phase may not have been get()'d before kill).
  protected function void flush_buckets();
    mbinit_event ev;
    while (ev_fifo.try_get(ev)) begin
      if (have_bucket && (ev.tstamp != bucket_t)) begin
        process_bucket();
        bucket.delete();
      end
      bucket.push_back(ev);
      bucket_t    = ev.tstamp;
      have_bucket = 1;
    end
    if (have_bucket && (bucket.size() > 0)) begin
      process_bucket();
      bucket.delete();
      have_bucket = 0;
    end
  endfunction

  // -------------------------------------------------------------------------
  // Process one timestamp bucket: Phase A settles context, Phase B checks.
  // -------------------------------------------------------------------------
  protected function void process_bucket();
    mbinit_event ev;
    // ---- Phase A: settle effective context (state / neg / lane-ctrl) ----
    foreach (bucket[i]) begin
      ev = bucket[i];
      case (ev.kind)
        MB_EVT_STATE:      apply_state(ev);
        MB_EVT_NEG_PARAMS: apply_neg(ev);
        MB_EVT_LANE_CTRL:  apply_lane_ctrl(ev);
        default: ;
      endcase
    end

    // XC-05 + RC-01: once context is known, check lane ctrl vs current state.
    if (state_seen && lc_seen) begin
      check_lane_ctrl();
      if (cur_state == MB_STATE_REPAIRCLK && repairclk_lane_ctrl_matches())
        saw_repairclk_lane_ctrl_good = 1;
    end

    // ---- Phase B: state-dependent checks against settled context ----
    foreach (bucket[i]) begin
      ev = bucket[i];
      case (ev.kind)
        MB_EVT_SB_MSG, MB_EVT_UNKNOWN: handle_lane_msg(ev);
        MB_EVT_PATTERN_WRITER:         handle_pw(ev);
        MB_EVT_PATTERN_READER:         handle_pr(ev);
        MB_EVT_PTTEST:                 handle_pttest(ev);
        MB_EVT_TXWIDTH_CHANGED:
          if (cur_state == MB_STATE_REPAIRMB) saw_repairmb_txwidth_pulse = 1;
        MB_EVT_INTEROP_FAIL: begin
          if (!mp_04_triggered) begin
            `uvm_info("MB_SB", "MP-04: interoperableParamsNotFound asserted", UVM_LOW)
            mp_04_triggered = 1;
          end
        end
        MB_EVT_FSM_DONE: begin
          if (!saw_fsm_done) begin
            `uvm_info("MB_SB", "MBINIT fsmCtrl_done asserted", UVM_LOW)
            saw_fsm_done = 1;
          end
        end
        MB_EVT_FSM_ERROR: begin
          if (!saw_fsm_error) begin
            `uvm_info("MB_SB", "MBINIT fsmCtrl_error asserted", UVM_LOW)
            saw_fsm_error = 1;
          end
        end
        default: ;
      endcase
    end
  endfunction

  // -------------------------------------------------------------------------
  // Phase A appliers
  // -------------------------------------------------------------------------
  protected function void apply_state(mbinit_event ev);
    state_seen      = 1;
    cur_state       = ev.state;
    cur_using_pw    = ev.using_pw;
    cur_using_pr    = ev.using_pr;
    cur_apply_lr    = ev.apply_lane_reversal;
    cur_local_phase = ev.local_clock_phase;

    case (ev.state)
      MB_STATE_CAL:        saw_state_cal        = 1;
      MB_STATE_REPAIRCLK:  saw_state_repairclk  = 1;
      MB_STATE_REPAIRVAL:  saw_state_repairval  = 1;
      MB_STATE_REVERSALMB: begin
        saw_state_reversalmb = 1;
        if (ev.using_pr) saw_lr03_pattern_reader_reversalmb = 1;  // LR-03
      end
      MB_STATE_REPAIRMB:   saw_state_repairmb   = 1;
      MB_STATE_TOMBTRAIN:  saw_state_tombtrain  = 1;
      default: ;
    endcase

    if (ev.apply_lane_reversal) saw_apply_lane_reversal = 1;  // LR-04
  endfunction

  protected function void apply_neg(mbinit_event ev);
    neg_valid = 1;
    neg_phase = ev.neg_clock_phase;
    if (!mp_02_verified && ev.neg_data_rate == 4'hF) begin
      `uvm_info("MB_SB", "MP-02: negotiated max common data rate observed", UVM_LOW)
      mp_02_verified = 1;
    end
    if (!mp_03_verified && ev.neg_clock_mode == 1'b1) begin
      `uvm_info("MB_SB", "MP-03: negotiated clock mode matches request", UVM_LOW)
      mp_03_verified = 1;
    end
  endfunction

  protected function void apply_lane_ctrl(mbinit_event ev);
    lc_seen        = 1;
    lc_tx_data_en  = ev.lc_tx_data_en;
    lc_tx_clk_en   = ev.lc_tx_clk_en;
    lc_tx_valid_en = ev.lc_tx_valid_en;
    lc_tx_track_en = ev.lc_tx_track_en;
    lc_rx_data_en  = ev.lc_rx_data_en;
    lc_rx_clk_en   = ev.lc_rx_clk_en;
    lc_rx_valid_en = ev.lc_rx_valid_en;
    lc_rx_track_en = ev.lc_rx_track_en;
  endfunction

  // -------------------------------------------------------------------------
  // Phase B handlers
  // -------------------------------------------------------------------------
  // Sideband lane message (or unknown) — qualify by src + dir.
  protected function void handle_lane_msg(mbinit_event ev);
    if (ev.src == MB_SRC_REQ_LANE && ev.dir == MB_DIR_TX) begin
      saw_req_tx = 1;
      if (ev.kind == MB_EVT_UNKNOWN) begin
        if (!saw_bad_req_tx) begin
          saw_bad_req_tx = 1;
          `uvm_error("MB_SB", $sformatf(
            "Requester TX has unrecognized MBINIT sideband fields: data=%032h op=%02h msgCode[21:14]=%02h msgSubcode[39:32]=%02h",
            ev.raw, ev.opcode, ev.msg_code, ev.subcode))
        end
      end
      else if (ev.role == MB_ROLE_REQ)
        decode_req_tx(ev.msg_kind);
    end
    else if (ev.src == MB_SRC_RSP_LANE && ev.dir == MB_DIR_TX) begin
      saw_rsp_tx = 1;
      if (ev.kind == MB_EVT_UNKNOWN) begin
        if (!saw_bad_rsp_tx) begin
          saw_bad_rsp_tx = 1;
          `uvm_error("MB_SB", $sformatf(
            "Responder TX has unrecognized MBINIT sideband fields: data=%032h op=%02h msgCode[21:14]=%02h msgSubcode[39:32]=%02h",
            ev.raw, ev.opcode, ev.msg_code, ev.subcode))
        end
      end
      else if (ev.role == MB_ROLE_RESP)
        decode_rsp_tx(ev.msg_kind);
    end
    else if (ev.src == MB_SRC_REQ_LANE && ev.dir == MB_DIR_RX) begin
      // Partner -> DUT requester. LR-01 "wait for resp": REVERSALMB_INIT_RESP.
      if (ev.kind == MB_EVT_SB_MSG && ev.role == MB_ROLE_RESP &&
          ev.msg_kind == MB_MSG_LR_INIT && !saw_lr_init_resp_rx) begin
        `uvm_info("MB_SB", "LR-01: REVERSALMB_INIT_RESP on requester RX (partner)", UVM_LOW)
        saw_lr_init_resp_rx = 1;
      end
    end
  endfunction

  protected function void decode_req_tx(mbinit_msg_kind_e mk);
    case (mk)
      MB_MSG_PARAM:     if (!saw_param_req_tx)     begin `uvm_info("MB_SB","MP-01: DUT req sent PARAM_CFG_REQ",UVM_LOW)            saw_param_req_tx=1;     end
      MB_MSG_CAL:       if (!saw_cal_req_tx)       begin `uvm_info("MB_SB","MC-01: DUT req sent CAL_DONE_REQ",UVM_LOW)             saw_cal_req_tx=1;       end
      MB_MSG_RCLK_INIT: if (!saw_rclk_init_req_tx) begin `uvm_info("MB_SB","REPAIRCLK: DUT req sent REPAIRCLK_INIT_REQ",UVM_LOW)   saw_rclk_init_req_tx=1; end
      MB_MSG_RCLK_RES:  if (!saw_rclk_res_req_tx)  begin `uvm_info("MB_SB","REPAIRCLK: DUT req sent REPAIRCLK_RESULT_REQ",UVM_LOW) saw_rclk_res_req_tx=1;  end
      MB_MSG_RCLK_DONE: if (!saw_rclk_done_req_tx) begin `uvm_info("MB_SB","RC-05: DUT req sent REPAIRCLK_DONE_REQ",UVM_LOW)       saw_rclk_done_req_tx=1; end
      MB_MSG_RVAL_INIT: if (!saw_rval_init_req_tx) begin `uvm_info("MB_SB","REPAIRVAL: DUT req sent REPAIRVAL_INIT_REQ",UVM_LOW)   saw_rval_init_req_tx=1; end
      MB_MSG_RVAL_RES:  if (!saw_rval_res_req_tx)  begin `uvm_info("MB_SB","REPAIRVAL: DUT req sent REPAIRVAL_RESULT_REQ",UVM_LOW) saw_rval_res_req_tx=1;  end
      MB_MSG_RVAL_DONE: if (!saw_rval_done_req_tx) begin `uvm_info("MB_SB","RV-07: DUT req sent REPAIRVAL_DONE_REQ",UVM_LOW)       saw_rval_done_req_tx=1; end
      MB_MSG_LR_INIT:   if (!saw_lr_init_req_tx)   begin `uvm_info("MB_SB","LR-01: DUT req sent REVERSALMB_INIT_REQ",UVM_LOW)      saw_lr_init_req_tx=1;   end
      MB_MSG_LR_RES:    if (!saw_lr_res_req_tx)    begin `uvm_info("MB_SB","REVERSALMB: DUT req sent REVERSALMB_RESULT_REQ",UVM_LOW) saw_lr_res_req_tx=1;  end
      MB_MSG_LR_DONE:   if (!saw_lr_done_req_tx)   begin `uvm_info("MB_SB","LR-06: DUT req sent REVERSALMB_DONE_REQ",UVM_LOW)      saw_lr_done_req_tx=1;   end
      MB_MSG_RM_START:  if (!saw_rm_start_req_tx)  begin `uvm_info("MB_SB","REPAIRMB: DUT req sent REPAIRMB_START_REQ",UVM_LOW)    saw_rm_start_req_tx=1;  end
      MB_MSG_RM_END:    if (!saw_rm_end_req_tx)    begin `uvm_info("MB_SB","RM-08: DUT req sent REPAIRMB_END_REQ",UVM_LOW)         saw_rm_end_req_tx=1;    end
      default: ; // LR_CLR / RM_APPLY: recognized but no dedicated req witness (matches legacy)
    endcase
  endfunction

  protected function void decode_rsp_tx(mbinit_msg_kind_e mk);
    case (mk)
      MB_MSG_PARAM:     if (!saw_param_resp_tx)     begin `uvm_info("MB_SB","MP-01: DUT rsp sent PARAM_CFG_RESP",UVM_LOW)           saw_param_resp_tx=1;     end
      MB_MSG_CAL:       if (!saw_cal_resp_tx)       begin `uvm_info("MB_SB","MC-02: DUT rsp sent CAL_DONE_RESP",UVM_LOW)            saw_cal_resp_tx=1;       end
      MB_MSG_RCLK_INIT: if (!saw_rclk_init_resp_tx) begin `uvm_info("MB_SB","REPAIRCLK: DUT rsp sent REPAIRCLK_INIT_RESP",UVM_LOW)  saw_rclk_init_resp_tx=1; end
      MB_MSG_RCLK_RES:  if (!saw_rclk_res_resp_tx)  begin `uvm_info("MB_SB","REPAIRCLK: DUT rsp sent REPAIRCLK_RESULT_RESP",UVM_LOW) saw_rclk_res_resp_tx=1; end
      MB_MSG_RCLK_DONE: if (!saw_rclk_done_resp_tx) begin `uvm_info("MB_SB","RC-05: DUT rsp sent REPAIRCLK_DONE_RESP",UVM_LOW)      saw_rclk_done_resp_tx=1; end
      MB_MSG_RVAL_INIT: if (!saw_rval_init_resp_tx) begin `uvm_info("MB_SB","REPAIRVAL: DUT rsp sent REPAIRVAL_INIT_RESP",UVM_LOW)  saw_rval_init_resp_tx=1; end
      MB_MSG_RVAL_RES:  if (!saw_rval_res_resp_tx)  begin `uvm_info("MB_SB","REPAIRVAL: DUT rsp sent REPAIRVAL_RESULT_RESP",UVM_LOW) saw_rval_res_resp_tx=1; end
      MB_MSG_RVAL_DONE: if (!saw_rval_done_resp_tx) begin `uvm_info("MB_SB","RV-07: DUT rsp sent REPAIRVAL_DONE_RESP",UVM_LOW)      saw_rval_done_resp_tx=1; end
      MB_MSG_LR_INIT:   if (!saw_lr_init_resp_tx)   begin `uvm_info("MB_SB","LR-01: DUT responder TX REVERSALMB_INIT_RESP",UVM_LOW) saw_lr_init_resp_tx=1;  end
      MB_MSG_LR_RES:    if (!saw_lr_res_resp_tx)    begin `uvm_info("MB_SB","REVERSALMB: DUT rsp sent REVERSALMB_RESULT_RESP",UVM_LOW) saw_lr_res_resp_tx=1; end
      MB_MSG_LR_DONE:   if (!saw_lr_done_resp_tx)   begin `uvm_info("MB_SB","LR-06: DUT rsp sent REVERSALMB_DONE_RESP",UVM_LOW)     saw_lr_done_resp_tx=1;  end
      MB_MSG_RM_START:  if (!saw_rm_start_resp_tx)  begin `uvm_info("MB_SB","REPAIRMB: DUT rsp sent REPAIRMB_START_RESP",UVM_LOW)   saw_rm_start_resp_tx=1; end
      MB_MSG_RM_END:    if (!saw_rm_end_resp_tx)    begin `uvm_info("MB_SB","RM-08: DUT rsp sent REPAIRMB_END_RESP",UVM_LOW)        saw_rm_end_resp_tx=1;   end
      default: ;
    endcase
  endfunction

  // PatternWriter request: RC-02/RV-03/LR-02/RM-01 type check + RC-02/RV-01 witnesses.
  protected function void handle_pw(mbinit_event ev);
    if (ev.svc_kind != MB_SVC_REQ) return;
    check_pattern_type(ev.pattern_type);
    if (cur_state == MB_STATE_REPAIRCLK && ev.pattern_type == PT_CLKREPAIR)
      saw_repairclk_pw_clkrepair = 1;
    if (cur_state == MB_STATE_REPAIRVAL && ev.pattern_type == PT_VALTRAIN) begin
      saw_rv01_pw_valtrain = 1;
      if (cur_using_pw) saw_rv01_using_pw = 1;
      if (neg_valid && (neg_phase & ~cur_local_phase))
        rv01_phase_constraint_violation = 1;
    end
  endfunction

  // PatternReader request: RC-02 / RV-01 reader-active witnesses.
  protected function void handle_pr(mbinit_event ev);
    if (ev.svc_kind != MB_SVC_REQ) return;
    if (cur_state == MB_STATE_REPAIRCLK && ev.pattern_type == PT_CLKREPAIR)
      saw_repairclk_pr_clkrepair = 1;
    if (cur_state == MB_STATE_REPAIRVAL && ev.pattern_type == PT_VALTRAIN)
      saw_rv01_repairval_reader_on = 1;
    // usingPatternReader in REPAIRVAL also counts (rolling context).
    if (cur_state == MB_STATE_REPAIRVAL && cur_using_pr)
      saw_rv01_repairval_reader_on = 1;
  endfunction

  // Tx point-test result beats in REPAIRMB (RM-02/05).
  protected function void handle_pttest(mbinit_event ev);
    if (ev.src != MB_SRC_PTTEST_REQ)   return;
    if (ev.svc_kind != MB_SVC_RESULT)  return;
    if (cur_state != MB_STATE_REPAIRMB) return;
    repairmb_pt_results_beats++;
    if ((|ev.pt_results) && !(&ev.pt_results))
      saw_rm02_heterogeneous_pt_repairmb = 1;
  endfunction

  // -------------------------------------------------------------------------
  // RC-01: REPAIRCLK lane-ctrl positive witness (same expectation as XC-05).
  // -------------------------------------------------------------------------
  protected function bit repairclk_lane_ctrl_matches();
    repairclk_lane_ctrl_matches =
      (lc_tx_data_en  == 16'h0) &&
      (lc_tx_clk_en   === 1'b1) &&
      (lc_tx_valid_en === 1'b1) &&
      (lc_tx_track_en === 1'b1) &&
      (lc_rx_data_en  == 16'h0) &&
      (lc_rx_clk_en   === 1'b1) &&
      (lc_rx_valid_en === 1'b1) &&
      (lc_rx_track_en === 1'b1);
  endfunction

  // XC-05: verify mbLaneCtrlIo matches expected values for the current state.
  protected function void check_lane_ctrl();
    bit exp_txData, exp_txClk, exp_txValid, exp_txTrack;
    bit exp_rxData, exp_rxClk, exp_rxValid, exp_rxTrack;
    bit skip_txValid, mismatch;
    skip_txValid = 0;
    mismatch     = 0;
    case (cur_state)
      MB_STATE_PARAM, MB_STATE_CAL: begin
        exp_txData=0; exp_txClk=0; exp_txValid=0; exp_txTrack=0;
        exp_rxData=0; exp_rxClk=0; exp_rxValid=0; exp_rxTrack=0;
      end
      MB_STATE_REPAIRCLK: begin
        exp_txData=0; exp_txClk=1; exp_txValid=1; exp_txTrack=1;
        exp_rxData=0; exp_rxClk=1; exp_rxValid=1; exp_rxTrack=1;
      end
      MB_STATE_REPAIRVAL: begin
        exp_txData=1; exp_txClk=1; exp_txValid=1; exp_txTrack=0;
        exp_rxData=0; exp_rxClk=1; exp_rxValid=1; exp_rxTrack=0;
        skip_txValid = 1;
      end
      MB_STATE_REVERSALMB, MB_STATE_REPAIRMB: begin
        exp_txData=1; exp_txClk=1; exp_txValid=1; exp_txTrack=1;
        exp_rxData=1; exp_rxClk=1; exp_rxValid=1; exp_rxTrack=0;
      end
      MB_STATE_TOMBTRAIN: begin
        exp_txData=0; exp_txClk=0; exp_txValid=0; exp_txTrack=0;
        exp_rxData=0; exp_rxClk=0; exp_rxValid=0; exp_rxTrack=0;
      end
      default: return;
    endcase
    if (lc_tx_data_en  !== {16{exp_txData}})  mismatch=1;
    if (lc_tx_clk_en   !== exp_txClk)         mismatch=1;
    if (!skip_txValid &&
        lc_tx_valid_en !== exp_txValid)        mismatch=1;
    if (lc_tx_track_en !== exp_txTrack)        mismatch=1;
    if (lc_rx_data_en  !== {16{exp_rxData}})   mismatch=1;
    if (lc_rx_clk_en   !== exp_rxClk)          mismatch=1;
    if (lc_rx_valid_en !== exp_rxValid)         mismatch=1;
    if (lc_rx_track_en !== exp_rxTrack)         mismatch=1;
    if (mismatch && !lane_ctrl_error) begin
      lane_ctrl_error = 1;
      `uvm_error("MB_SB", $sformatf(
        "XC-05: lane ctrl mismatch in state %0d: txData=%04h(exp %04h) txClk=%0b(exp %0b) txValid=%0b(skip=%0b) txTrack=%0b(exp %0b) rxData=%04h(exp %04h) rxClk=%0b(exp %0b) rxValid=%0b(exp %0b) rxTrack=%0b(exp %0b)",
        cur_state,
        lc_tx_data_en, {16{exp_txData}},
        lc_tx_clk_en, exp_txClk,
        lc_tx_valid_en, skip_txValid,
        lc_tx_track_en, exp_txTrack,
        lc_rx_data_en, {16{exp_rxData}},
        lc_rx_clk_en, exp_rxClk,
        lc_rx_valid_en, exp_rxValid,
        lc_rx_track_en, exp_rxTrack))
    end
  endfunction

  // RC-02/RV-03/LR-02/RM-01: pattern type vs state (on a patternWriter request).
  protected function void check_pattern_type(logic [1:0] ptype);
    case (cur_state)
      MB_STATE_REPAIRCLK: begin
        if (ptype !== PT_CLKREPAIR && ptype !== PT_VALTRAIN) begin
          pattern_type_error = 1;
          `uvm_error("MB_SB", $sformatf(
            "RC-02: patternWriter type=%0h in REPAIRCLK; expected CLKREPAIR(0) or VALTRAIN(1)", ptype))
        end
      end
      MB_STATE_REPAIRVAL: begin
        if (ptype !== PT_VALTRAIN) begin
          pattern_type_error = 1;
          `uvm_error("MB_SB", $sformatf(
            "RV-03: patternWriter type=%0h in REPAIRVAL; expected VALTRAIN(1)", ptype))
        end
      end
      MB_STATE_REVERSALMB: begin
        if (ptype !== PT_PERLANEID) begin
          pattern_type_error = 1;
          `uvm_error("MB_SB", $sformatf(
            "LR-02: patternWriter type=%0h in REVERSALMB; expected PERLANEID(2)", ptype))
        end
      end
      MB_STATE_REPAIRMB: begin
        if (ptype !== PT_PERLANEID) begin
          pattern_type_error = 1;
          `uvm_error("MB_SB", $sformatf(
            "RM-01: patternWriter type=%0h in REPAIRMB; expected PERLANEID(2)", ptype))
        end
      end
      default: ;
    endcase
  endfunction

  // ====================== final requirement checks ==========================
  // Identical expect_* logic + error messages to the legacy scoreboard, so test
  // pass/fail semantics are preserved. Flush the bucket/FIFO tail first.
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    flush_buckets();

    `uvm_info("MB_SB", $sformatf(
      "Summary: req_tx=%0b rsp_tx=%0b bad_req=%0b bad_rsp=%0b param_req=%0b param_resp=%0b mp02=%0b mp03=%0b cal=%0b fsm_done=%0b fsm_err=%0b lane_ctrl_err=%0b pat_type_err=%0b lr03_pr_revmb=%0b apply_lane_rev=%0b",
      saw_req_tx, saw_rsp_tx, saw_bad_req_tx, saw_bad_rsp_tx,
      saw_param_req_tx, saw_param_resp_tx, mp_02_verified, mp_03_verified,
      saw_cal_req_tx, saw_fsm_done, saw_fsm_error,
      lane_ctrl_error, pattern_type_error,
      saw_lr03_pattern_reader_reversalmb, saw_apply_lane_reversal), UVM_LOW)

    if (expect_param_messages && !saw_req_tx)
      `uvm_error("MB_SB","No requester sideband TX was observed")
    if (expect_param_messages && !saw_rsp_tx)
      `uvm_error("MB_SB","No responder sideband TX was observed")

    if (expect_param_messages) begin
      if (!saw_param_req_tx)
        `uvm_error("MB_SB","MP-01 FAILED: requester never sent PARAM_CFG_REQ")
      if (!saw_param_resp_tx)
        `uvm_error("MB_SB","MP-01 FAILED: responder never sent PARAM_CFG_RESP")
    end

    if (expect_param_common_rate && !mp_02_verified)
      `uvm_error("MB_SB","MP-02 FAILED: negotiated maxDataRate did not match expected common rate")

    if (expect_param_negotiation && !mp_03_verified)
      `uvm_error("MB_SB","MP-03 FAILED: negotiated clockMode did not match request")

    if (expect_interop_failure && !mp_04_triggered)
      `uvm_error("MB_SB","MP-04 FAILED: interoperableParamsNotFound never asserted")

    if (expect_mbinit_through_cal) begin
      if (!saw_param_req_tx)
        `uvm_error("MB_SB","MP-01 FAILED (CAL test): requester never sent PARAM_CFG_REQ")
      if (!saw_param_resp_tx)
        `uvm_error("MB_SB","MP-01 FAILED (CAL test): responder never sent PARAM_CFG_RESP")
      if (!mp_02_verified)
        `uvm_error("MB_SB","MP-02 FAILED (CAL test): negotiated maxDataRate did not match expected common rate")
      if (!mp_03_verified)
        `uvm_error("MB_SB","MP-03 FAILED (CAL test): negotiated clockMode did not match request")
      if (!saw_state_cal)
        `uvm_error("MB_SB","MP-06 FAILED: PARAM did not exit to CAL")
      if (!saw_cal_req_tx)
        `uvm_error("MB_SB","MC-01 FAILED: requester never sent CAL_DONE_REQ")
      if (!saw_cal_resp_tx)
        `uvm_error("MB_SB","MC-02 FAILED: responder never sent CAL_DONE_RESP")
      if (!saw_state_repairclk)
        `uvm_error("MB_SB","MC-02 FAILED: CAL did not exit to REPAIRCLK")
    end

    if (expect_mbinit_through_repairclk) begin
      if (!saw_param_req_tx)
        `uvm_error("MB_SB","MP-01 FAILED (REPAIRCLK test): requester never sent PARAM_CFG_REQ")
      if (!saw_param_resp_tx)
        `uvm_error("MB_SB","MP-01 FAILED (REPAIRCLK test): responder never sent PARAM_CFG_RESP")
      if (!mp_02_verified)
        `uvm_error("MB_SB","MP-02 FAILED (REPAIRCLK test): negotiated maxDataRate did not match expected common rate")
      if (!mp_03_verified)
        `uvm_error("MB_SB","MP-03 FAILED (REPAIRCLK test): negotiated clockMode did not match request")
      if (!saw_state_cal)
        `uvm_error("MB_SB","MP-06 FAILED (REPAIRCLK test): PARAM did not exit to CAL")
      if (!saw_cal_req_tx)
        `uvm_error("MB_SB","MC-01 FAILED (REPAIRCLK test): requester never sent CAL_DONE_REQ")
      if (!saw_cal_resp_tx)
        `uvm_error("MB_SB","MC-02 FAILED (REPAIRCLK test): responder never sent CAL_DONE_RESP")
      if (!saw_state_repairclk)
        `uvm_error("MB_SB","MC-02 FAILED (REPAIRCLK test): CAL did not exit to REPAIRCLK")
      if (!saw_repairclk_lane_ctrl_good)
        `uvm_error("MB_SB","RC-01 FAILED: never observed REPAIRCLK lane ctrl matching spec (clock/track + Rx enables)")
      if (!saw_repairclk_pw_clkrepair)
        `uvm_error("MB_SB","RC-02 FAILED: never observed patternWriter CLKREPAIR in REPAIRCLK")
      if (!saw_repairclk_pr_clkrepair)
        `uvm_error("MB_SB","RC-02 FAILED: never observed patternReader CLKREPAIR request in REPAIRCLK")
      if (!saw_rclk_init_req_tx)
        `uvm_error("MB_SB","REPAIRCLK FAILED: requester never sent REPAIRCLK_INIT_REQ")
      if (!saw_rclk_init_resp_tx)
        `uvm_error("MB_SB","REPAIRCLK FAILED: responder never sent REPAIRCLK_INIT_RESP")
      if (!saw_rclk_res_req_tx)
        `uvm_error("MB_SB","REPAIRCLK FAILED: requester never sent REPAIRCLK_RESULT_REQ")
      if (!saw_rclk_done_req_tx)
        `uvm_error("MB_SB","RC-05 FAILED: requester never sent REPAIRCLK_DONE_REQ")
      if (!saw_state_repairval)
        `uvm_error("MB_SB","RC-05 FAILED: REPAIRCLK did not exit to REPAIRVAL")
    end

    if (expect_repairclk_rc03) begin
      if (!saw_rclk_init_req_tx)
        `uvm_error("MB_SB","RC-03 FAILED: requester never sent REPAIRCLK_INIT_REQ")
      if (!saw_rclk_res_req_tx)
        `uvm_error("MB_SB","RC-03 FAILED: requester never sent REPAIRCLK_RESULT_REQ (failure path)")
      if (!saw_fsm_error)
        `uvm_error("MB_SB","RC-03 FAILED: fsmCtrl_error never asserted for unrepairable clock/track")
      if (saw_state_repairval)
        `uvm_error("MB_SB","RC-03 FAILED: entered REPAIRVAL after unrepairable REPAIRCLK (unexpected)")
    end

    if (expect_full_mbinit) begin
      if (!saw_state_cal)
        `uvm_error("MB_SB","MP-06 FAILED: PARAM did not exit to CAL")
      if (!saw_cal_req_tx)
        `uvm_error("MB_SB","MC-01 FAILED: requester never sent CAL_DONE_REQ")
      if (!saw_cal_resp_tx)
        `uvm_error("MB_SB","MC-02 FAILED: responder never sent CAL_DONE_RESP")
      if (!saw_state_repairclk)
        `uvm_error("MB_SB","MC-02 FAILED: CAL did not exit to REPAIRCLK")
      if (!saw_rclk_init_req_tx)
        `uvm_error("MB_SB","REPAIRCLK FLOW FAILED: requester never sent REPAIRCLK_INIT_REQ")
      if (!saw_rclk_res_req_tx)
        `uvm_error("MB_SB","REPAIRCLK FLOW FAILED: requester never sent REPAIRCLK_RESULT_REQ")
      if (!saw_rclk_done_req_tx)
        `uvm_error("MB_SB","RC-05 FAILED: requester never sent REPAIRCLK_DONE_REQ")
      if (!saw_state_repairval)
        `uvm_error("MB_SB","RC-05 FAILED: REPAIRCLK did not exit to REPAIRVAL")
      if (!saw_rval_init_req_tx)
        `uvm_error("MB_SB","REPAIRVAL FLOW FAILED: requester never sent REPAIRVAL_INIT_REQ")
      if (!saw_rval_res_req_tx)
        `uvm_error("MB_SB","REPAIRVAL FLOW FAILED: requester never sent REPAIRVAL_RESULT_REQ")
      if (!saw_rval_done_req_tx)
        `uvm_error("MB_SB","RV-07 FAILED: requester never sent REPAIRVAL_DONE_REQ")
      if (!saw_state_reversalmb)
        `uvm_error("MB_SB","RV-07 FAILED: REPAIRVAL did not exit to REVERSALMB")
      if (!saw_lr_init_req_tx)
        `uvm_error("MB_SB","LR-01 FAILED: requester never sent REVERSALMB_INIT_REQ")
      if (!saw_lr_init_resp_rx)
        `uvm_error("MB_SB","LR-01 FAILED: REVERSALMB_INIT_RESP never observed on requester RX (partner)")
      if (expect_lr03_pattern_reader && !saw_lr03_pattern_reader_reversalmb)
        `uvm_error("MB_SB",
          "LR-03 FAILED: usingPatternReader not observed in REVERSALMB (responder PatternReader path)")
      if (!saw_lr_res_req_tx)
        `uvm_error("MB_SB","REVERSALMB FLOW FAILED: requester never sent REVERSALMB_RESULT_REQ")
      if (!saw_lr_done_req_tx)
        `uvm_error("MB_SB","LR-06 FAILED: requester never sent REVERSALMB_DONE_REQ")
      if (!saw_state_repairmb)
        `uvm_error("MB_SB","LR-06 FAILED: REVERSALMB did not exit to REPAIRMB")
      if (!saw_rm_start_req_tx)
        `uvm_error("MB_SB","REPAIRMB FLOW FAILED: requester never sent REPAIRMB_START_REQ")
      if (!saw_rm_end_req_tx)
        `uvm_error("MB_SB","RM-08 FAILED: requester never sent REPAIRMB_END_REQ")
      if (!saw_state_tombtrain)
        `uvm_error("MB_SB","RM-08 FAILED: REPAIRMB did not exit toward MBTRAIN")
      if (expect_lr04_apply_lane_reversal && !saw_apply_lane_reversal)
        `uvm_error("MB_SB","LR-04 FAILED: applyLaneReversal never asserted (expected fail-then-pass REVERSALMB)")
      if (expect_rm02_per_lane_reader && !saw_rm02_heterogeneous_pt_repairmb)
        `uvm_error("MB_SB",
          "RM-02 FAILED: never observed heterogeneous Tx point-test per-lane bits in REPAIRMB (expect mixed pass/fail on ptTestResults)")
      if (expect_rv01_checks) begin
        if (!saw_rv01_pw_valtrain)
          `uvm_error("MB_SB","RV-01 FAILED: never observed patternWriter VALTRAIN in REPAIRVAL")
        if (!saw_rv01_repairval_reader_on)
          `uvm_error("MB_SB","RV-01 FAILED: never observed responder patternReader activity in REPAIRVAL (usingPatternReader / VALTRAIN req)")
        if (!saw_rv01_using_pw)
          `uvm_error("MB_SB","RV-01 FAILED: usingPatternWriter not set during VALTRAIN on requester")
        if (rv01_phase_constraint_violation)
          `uvm_error("MB_SB","RV-01 FAILED: negotiated_clockPhase is not (local & remote) — see MBInitSM negotiated vs local")
      end
    end

    if (expect_fsm_done && !saw_fsm_done)
      `uvm_error("MB_SB","MBINIT FAILED: fsmCtrl_done never asserted")

    if (expect_fsm_error && !saw_fsm_error)
      `uvm_error("MB_SB","Expected fsmCtrl_error but it never asserted")

    if (expect_rm07_repairmb_unrepairable) begin
      if (!saw_state_repairmb)
        `uvm_error("MB_SB","RM-07 FAILED: never entered REPAIRMB before error")
      if (!saw_rm_start_req_tx)
        `uvm_error("MB_SB","RM-07 FAILED: never saw REPAIRMB_START_REQ")
      if (saw_rm_end_req_tx)
        `uvm_error("MB_SB","RM-07 FAILED: REPAIRMB_END_REQ observed (unexpected success exit)")
    end

    if (expect_rm05_post_repair_witness) begin
      if (!saw_state_repairmb)
        `uvm_error("MB_SB","RM-05 FAILED: never entered REPAIRMB")
      if (!saw_rm_start_req_tx)
        `uvm_error("MB_SB","RM-05 FAILED: never saw REPAIRMB_START_REQ")
      if (repairmb_pt_results_beats < 2)
        `uvm_error("MB_SB", $sformatf(
          "RM-05 FAILED: expected ≥2 Tx point-test result beats in REPAIRMB, saw %0d",
          repairmb_pt_results_beats))
      if (!saw_repairmb_txwidth_pulse)
        `uvm_error("MB_SB",
          "RM-05 FAILED: expected io_txWidthChanged pulse in REPAIRMB (width degrade after first half-fault PT)")
    end

    if (!expect_fsm_error && saw_fsm_error)
      `uvm_error("MB_SB","Unexpected fsmCtrl_error on success-path test")

    if (expect_lane_ctrl_checks && lane_ctrl_error)
      `uvm_error("MB_SB","XC-05 FAILED: mbLaneCtrlIo mismatch observed (see earlier errors for details)")
    if (expect_pattern_type_checks && pattern_type_error)
      `uvm_error("MB_SB","RC-02/RV-03/LR-02/RM-01 FAILED: patternWriter type mismatch observed (see earlier errors)")
  endfunction

endclass
`endif
