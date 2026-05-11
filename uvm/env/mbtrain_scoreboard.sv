`ifndef MBTRAIN_SCOREBOARD_SV
`define MBTRAIN_SCOREBOARD_SV

// SB field extraction (opcode[4:0], msgCode[21:14], msgSubcode[39:32])
`define MT_OP(d)  d[4:0]
`define MT_MC(d)  d[21:14]
`define MT_SC(d)  d[39:32]

`define MT_OP_NODATA 5'h12
`define MT_MC_REQ    8'hB5
`define MT_MC_RESP   8'hBA

`define MT_SC_VV_START  8'h00
`define MT_SC_VV_END    8'h01
`define MT_SC_DV_START  8'h02
`define MT_SC_DV_END    8'h03
`define MT_SC_SI_DONE   8'h04
`define MT_SC_TC_DONE   8'h05
`define MT_SC_RCC_START 8'h06
`define MT_SC_RCC_DONE  8'h07
`define MT_SC_VTC_START 8'h08
`define MT_SC_VTC_DONE  8'h09
`define MT_SC_VTV_START 8'h0A
`define MT_SC_VTV_DONE  8'h0B
`define MT_SC_DC1_START 8'h0C
`define MT_SC_DC1_END   8'h0D
`define MT_SC_DTV_START 8'h0E
`define MT_SC_DTV_END   8'h10
`define MT_SC_RDS_START 8'h11
`define MT_SC_RDS_END   8'h12
`define MT_SC_DC2_START 8'h13
`define MT_SC_DC2_END   8'h14
`define MT_SC_LS_START  8'h15
`define MT_SC_LS_DONE   8'h19

class mbtrain_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(mbtrain_scoreboard)

  uvm_analysis_export #(mbtrain_transaction) item_collected_export;
  uvm_tlm_analysis_fifo #(mbtrain_transaction) item_collected_fifo;

  localparam logic [3:0] MT_ST_VALVREF          = 4'h0;
  localparam logic [3:0] MT_ST_DATAVREF         = 4'h1;
  localparam logic [3:0] MT_ST_SPEEDIDLE        = 4'h2;
  localparam logic [3:0] MT_ST_TXSELFCAL        = 4'h3;
  localparam logic [3:0] MT_ST_RXCLKCAL         = 4'h4;
  localparam logic [3:0] MT_ST_VALTRAINCENTER   = 4'h5;
  localparam logic [3:0] MT_ST_VALTRAINVREF     = 4'h6;
  localparam logic [3:0] MT_ST_DATATRAINCENTER1 = 4'h7;
  localparam logic [3:0] MT_ST_DATATRAINVREF    = 4'h8;
  localparam logic [3:0] MT_ST_RXDESKEW         = 4'h9;
  localparam logic [3:0] MT_ST_DATATRAINCENTER2 = 4'hA;
  localparam logic [3:0] MT_ST_LINKSPEED        = 4'hB;

  localparam logic [1:0] PAT_VALTRAIN = 2'h1;
  localparam logic [1:0] PAT_LFSR     = 2'h3;

  bit saw_vv_start_req, saw_vv_start_rsp;
  bit saw_vv_end_req,   saw_vv_end_rsp;
  bit saw_dv_start_req, saw_dv_start_rsp;
  bit saw_dv_end_req,   saw_dv_end_rsp;
  bit saw_si_done_req,  saw_si_done_rsp;
  bit saw_tc_done_req,  saw_tc_done_rsp;
  bit saw_rcc_start_req, saw_rcc_done_req;
  bit saw_vtc_start_req, saw_vtc_done_req;
  bit saw_vtv_start_req, saw_vtv_done_req;
  bit saw_dc1_start_req, saw_dc1_end_req;
  bit saw_dtv_start_req, saw_dtv_end_req;
  bit saw_rds_start_req, saw_rds_end_req;
  bit saw_dc2_start_req, saw_dc2_end_req;
  bit saw_ls_start_req,  saw_ls_done_req;

  bit saw_state_valvref;
  bit saw_state_datavref;
  bit saw_state_speedidle;
  bit saw_state_txselfcal;
  bit saw_state_rxclkcal;
  bit saw_fsm_done;
  bit saw_fsm_error;

  bit saw_vv_lane_ctrl;
  bit saw_vv_phase_center;
  bit saw_vv_valtrain_params;
  bit saw_vv_success;
  bit saw_vv_partner_valtrain;

  bit saw_dv_lfsr_params;
  bit saw_dv_success;

  bit lane_ctrl_error;
  bit train_param_error;

  bit expect_full_mbtrain    = 1;
  bit expect_valvref_checks  = 1;
  bit expect_datavref_checks = 1;
  bit expect_txselfcal_checks = 0;
  bit expect_rxclkcal_checks  = 0;
  bit expect_fsm_done        = 1;
  bit expect_fsm_error       = 0;
  bit debug_txselfcal        = 0;
  logic [15:0] expected_max_error_threshold = 16'hFFFF;

  int tc_cycles;
  int tc_req_tx_valid_count;
  int tc_req_tx_handshake_count;
  int tc_rsp_tx_valid_count;
  int tc_rsp_tx_handshake_count;
  bit tc_saw_start;
  bit tc_saw_done;
  bit tc_saw_req_match;
  bit tc_saw_rsp_match;
  bit tc_saw_to_rxclkcal;
  bit [3:0] prev_current_state = 4'hF;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    item_collected_export = new("item_collected_export", this);
    item_collected_fifo   = new("item_collected_fifo", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    item_collected_export.connect(item_collected_fifo.analysis_export);
  endfunction

  function bit is_req_subcode(logic [127:0] d, logic [7:0] subcode);
    return (`MT_OP(d) == `MT_OP_NODATA &&
            `MT_MC(d) == `MT_MC_REQ &&
            `MT_SC(d) == subcode);
  endfunction

  function bit is_rsp_subcode(logic [127:0] d, logic [7:0] subcode);
    return (`MT_OP(d) == `MT_OP_NODATA &&
            `MT_MC(d) == `MT_MC_RESP &&
            `MT_SC(d) == subcode);
  endfunction

  task run_phase(uvm_phase phase);
    mbtrain_transaction tx;
    forever begin
      item_collected_fifo.get(tx);

      if (tx.tx_valid)     decode_req_tx(tx.tx_data);
      if (tx.rsp_tx_valid) decode_rsp_tx(tx.rsp_tx_data);
      collect_txselfcal_debug(tx);

      case (tx.currentState)
        MT_ST_VALVREF:   saw_state_valvref = 1;
        MT_ST_DATAVREF:  saw_state_datavref = 1;
        MT_ST_SPEEDIDLE: saw_state_speedidle = 1;
        MT_ST_TXSELFCAL: saw_state_txselfcal = 1;
        MT_ST_RXCLKCAL:  saw_state_rxclkcal = 1;
        default: ;
      endcase

      check_lane_ctrl(tx);
      check_valvref_training(tx);
      check_datavref_training(tx);

      if (tx.fsm_done && !saw_fsm_done) begin
        `uvm_info("MT_SB", "MBTRAIN fsmCtrl_done asserted", UVM_LOW)
        saw_fsm_done = 1;
      end
      if (tx.fsm_error && !saw_fsm_error) begin
        `uvm_info("MT_SB", "MBTRAIN fsmCtrl_error asserted", UVM_LOW)
        saw_fsm_error = 1;
      end

      prev_current_state = tx.currentState;
    end
  endtask

  function void collect_txselfcal_debug(mbtrain_transaction tx);
    if (tx.currentState == MT_ST_TXSELFCAL) begin
      tc_cycles++;
      if (tx.trainingTxSelfCalStart)
        tc_saw_start = 1;
      if (tx.trainingTxSelfCalDone)
        tc_saw_done = 1;
      if (tx.tx_valid) begin
        tc_req_tx_valid_count++;
        if (is_req_subcode(tx.tx_data, `MT_SC_TC_DONE))
          tc_saw_req_match = 1;
      end
      if (tx.tx_valid && tx.tx_ready)
        tc_req_tx_handshake_count++;
      if (tx.rsp_tx_valid) begin
        tc_rsp_tx_valid_count++;
        if (is_rsp_subcode(tx.rsp_tx_data, `MT_SC_TC_DONE))
          tc_saw_rsp_match = 1;
      end
      if (tx.rsp_tx_valid && tx.rsp_tx_ready)
        tc_rsp_tx_handshake_count++;
    end

    if (prev_current_state == MT_ST_TXSELFCAL &&
        tx.currentState == MT_ST_RXCLKCAL)
      tc_saw_to_rxclkcal = 1;

    if (debug_txselfcal &&
        (tx.currentState == MT_ST_TXSELFCAL ||
         prev_current_state == MT_ST_TXSELFCAL ||
         (tx.tx_valid && is_req_subcode(tx.tx_data, `MT_SC_TC_DONE)) ||
         (tx.rsp_tx_valid && is_rsp_subcode(tx.rsp_tx_data, `MT_SC_TC_DONE)))) begin
      `uvm_info("MT_SB", $sformatf(
        "TXSELFCAL trace: state=%0h start=%0b done=%0b req_tx_v/r=%0b/%0b req_data=%032h req_tc=%0b rsp_tx_v/r=%0b/%0b rsp_data=%032h rsp_tc=%0b fsm_done=%0b err=%0b",
        tx.currentState,
        tx.trainingTxSelfCalStart,
        tx.trainingTxSelfCalDone,
        tx.tx_valid, tx.tx_ready, tx.tx_data, is_req_subcode(tx.tx_data, `MT_SC_TC_DONE),
        tx.rsp_tx_valid, tx.rsp_tx_ready, tx.rsp_tx_data, is_rsp_subcode(tx.rsp_tx_data, `MT_SC_TC_DONE),
        tx.fsm_done, tx.fsm_error), UVM_LOW)
    end
  endfunction

  function void check_lane_ctrl(mbtrain_transaction tx);
    logic [15:0] exp_tx_data;
    logic        exp_tx_clk, exp_tx_valid, exp_tx_track;
    logic [15:0] exp_rx_data;
    logic        exp_rx_clk, exp_rx_valid, exp_rx_track;
    string state_name;

    exp_tx_data = 16'hFFFF;
    exp_tx_clk = 1;
    exp_tx_valid = 1;
    exp_tx_track = 1;
    exp_rx_data = 16'hFFFF;
    exp_rx_clk = 1;
    exp_rx_valid = 1;
    exp_rx_track = 0;

    case (tx.currentState)
      MT_ST_VALVREF:          state_name = "VALVREF";
      MT_ST_DATAVREF:         state_name = "DATAVREF";
      MT_ST_SPEEDIDLE:        state_name = "SPEEDIDLE";
      MT_ST_VALTRAINCENTER:   state_name = "VALTRAINCENTER";
      MT_ST_VALTRAINVREF:     state_name = "VALTRAINVREF";
      MT_ST_DATATRAINCENTER1: state_name = "DATATRAINCENTER1";
      MT_ST_DATATRAINVREF:    state_name = "DATATRAINVREF";
      MT_ST_DATATRAINCENTER2: state_name = "DATATRAINCENTER2";
      MT_ST_LINKSPEED:        state_name = "LINKSPEED";
      MT_ST_TXSELFCAL: begin
        state_name = "TXSELFCAL";
        exp_tx_data = 16'h0000;
        exp_tx_clk = 0;
        exp_tx_valid = 0;
        exp_tx_track = 0;
        exp_rx_data = 16'h0000;
        exp_rx_clk = 0;
        exp_rx_valid = 0;
        exp_rx_track = 0;
      end
      MT_ST_RXCLKCAL, MT_ST_RXDESKEW: begin
        if (tx.currentState == MT_ST_RXCLKCAL)
          state_name = "RXCLKCAL";
        else
          state_name = "RXDESKEW";
        exp_rx_data = 16'h0000;
      end
      default: return;
    endcase

    if (tx.currentState == MT_ST_VALVREF &&
        tx.mbLaneCtrl_txDataEn == 16'hFFFF &&
        tx.mbLaneCtrl_txTrackEn &&
        tx.mbLaneCtrl_rxClkEn &&
        tx.mbLaneCtrl_rxValidEn)
      saw_vv_lane_ctrl = 1;

    if (tx.mbLaneCtrl_txDataEn !== exp_tx_data ||
        tx.mbLaneCtrl_txClkEn !== exp_tx_clk ||
        tx.mbLaneCtrl_txValidEn !== exp_tx_valid ||
        tx.mbLaneCtrl_txTrackEn !== exp_tx_track ||
        tx.mbLaneCtrl_rxDataEn !== exp_rx_data ||
        tx.mbLaneCtrl_rxClkEn !== exp_rx_clk ||
        tx.mbLaneCtrl_rxValidEn !== exp_rx_valid ||
        tx.mbLaneCtrl_rxTrackEn !== exp_rx_track) begin
      lane_ctrl_error = 1;
      `uvm_error("MT_SB", $sformatf(
        "XC-05 [%s] lane ctrl mismatch: txData=%04h/%04h txClk=%0b/%0b txValid=%0b/%0b txTrack=%0b/%0b rxData=%04h/%04h rxClk=%0b/%0b rxValid=%0b/%0b rxTrack=%0b/%0b",
        state_name,
        tx.mbLaneCtrl_txDataEn, exp_tx_data,
        tx.mbLaneCtrl_txClkEn, exp_tx_clk,
        tx.mbLaneCtrl_txValidEn, exp_tx_valid,
        tx.mbLaneCtrl_txTrackEn, exp_tx_track,
        tx.mbLaneCtrl_rxDataEn, exp_rx_data,
        tx.mbLaneCtrl_rxClkEn, exp_rx_clk,
        tx.mbLaneCtrl_rxValidEn, exp_rx_valid,
        tx.mbLaneCtrl_rxTrackEn, exp_rx_track))
    end
  endfunction

  function void check_common_rx_params(mbtrain_transaction tx,
                                       string req_name,
                                       logic [1:0] pattern_type,
                                       logic [3:0] clock_phase,
                                       logic [2:0] data_pattern,
                                       logic [2:0] valid_pattern,
                                       logic pattern_mode,
                                       logic [15:0] iteration_count,
                                       logic [15:0] idle_count,
                                       logic [15:0] burst_count,
                                       logic [15:0] max_error_threshold,
                                       logic comparison_mode,
                                       logic [1:0] exp_pattern_type,
                                       logic [2:0] exp_data_pattern,
                                       logic [2:0] exp_valid_pattern,
                                       logic [15:0] exp_burst_count);
    if (clock_phase !== 4'h0 ||
        pattern_type !== exp_pattern_type ||
        data_pattern !== exp_data_pattern ||
        valid_pattern !== exp_valid_pattern ||
        pattern_mode !== 1'b0 ||
        iteration_count !== 16'h0001 ||
        idle_count !== 16'h0000 ||
        burst_count !== exp_burst_count ||
        max_error_threshold !== expected_max_error_threshold ||
        comparison_mode !== 1'b0) begin
      train_param_error = 1;
      `uvm_error("MT_SB", $sformatf(
        "%s params mismatch: phase=%0h patternType=%0h dataPattern=%0h validPattern=%0h mode=%0b iter=%0d idle=%0d burst=%0d threshold=%0d cmp=%0b; expected phase=0 patternType=%0h dataPattern=%0h validPattern=%0h mode=0 iter=1 idle=0 burst=%0d threshold=%0d cmp=0",
        req_name, clock_phase, pattern_type, data_pattern, valid_pattern,
        pattern_mode, iteration_count, idle_count, burst_count,
        max_error_threshold, comparison_mode, exp_pattern_type,
        exp_data_pattern, exp_valid_pattern, exp_burst_count,
        expected_max_error_threshold))
    end
  endfunction

  function void check_valvref_training(mbtrain_transaction tx);
    if (tx.currentState != MT_ST_VALVREF)
      return;

    if (tx.rxPtTestReq_start) begin
      check_common_rx_params(tx, "VV rxPtTestReq",
        tx.rxPtTestReq_patternType, tx.rxPtTestReq_clockPhase,
        tx.rxPtTestReq_dataPattern, tx.rxPtTestReq_validPattern,
        tx.rxPtTestReq_patternMode, tx.rxPtTestReq_iterationCount,
        tx.rxPtTestReq_idleCount, tx.rxPtTestReq_burstCount,
        tx.rxPtTestReq_maxErrorThreshold, tx.rxPtTestReq_comparisonMode,
        PAT_VALTRAIN, 3'h1, 3'h0, 16'd1024);
      saw_vv_phase_center = (tx.rxPtTestReq_clockPhase == 4'h0);
      saw_vv_valtrain_params = (tx.rxPtTestReq_patternType == PAT_VALTRAIN &&
                                tx.rxPtTestReq_validPattern == 3'h0 &&
                                tx.rxPtTestReq_burstCount == 16'd1024);
    end

    if (tx.rxEyeSweepReq_start) begin
      check_common_rx_params(tx, "VV rxEyeSweepReq",
        tx.rxEyeSweepReq_patternType, tx.rxEyeSweepReq_clockPhase,
        tx.rxEyeSweepReq_dataPattern, tx.rxEyeSweepReq_validPattern,
        tx.rxEyeSweepReq_patternMode, tx.rxEyeSweepReq_iterationCount,
        tx.rxEyeSweepReq_idleCount, tx.rxEyeSweepReq_burstCount,
        tx.rxEyeSweepReq_maxErrorThreshold, tx.rxEyeSweepReq_comparisonMode,
        PAT_VALTRAIN, 3'h1, 3'h0, 16'd1024);
      saw_vv_phase_center = (tx.rxEyeSweepReq_clockPhase == 4'h0);
      saw_vv_valtrain_params = (tx.rxEyeSweepReq_patternType == PAT_VALTRAIN &&
                                tx.rxEyeSweepReq_validPattern == 3'h0 &&
                                tx.rxEyeSweepReq_burstCount == 16'd1024);
    end

    if ((tx.rxPtTestResp_start && tx.rxPtTestResp_patternType == PAT_VALTRAIN) ||
        (tx.rxEyeSweepResp_start && tx.rxEyeSweepResp_patternType == PAT_VALTRAIN))
      saw_vv_partner_valtrain = 1;

    if (tx.trainingRespResultsValid && tx.trainingRespResultsBits == 16'hFFFF)
      saw_vv_success = 1;
  endfunction

  function void check_datavref_training(mbtrain_transaction tx);
    if (tx.currentState != MT_ST_DATAVREF)
      return;

    if (tx.rxPtTestReq_start) begin
      check_common_rx_params(tx, "DV rxPtTestReq",
        tx.rxPtTestReq_patternType, tx.rxPtTestReq_clockPhase,
        tx.rxPtTestReq_dataPattern, tx.rxPtTestReq_validPattern,
        tx.rxPtTestReq_patternMode, tx.rxPtTestReq_iterationCount,
        tx.rxPtTestReq_idleCount, tx.rxPtTestReq_burstCount,
        tx.rxPtTestReq_maxErrorThreshold, tx.rxPtTestReq_comparisonMode,
        PAT_LFSR, 3'h1, 3'h0, 16'd4096);
      saw_dv_lfsr_params = (tx.rxPtTestReq_patternType == PAT_LFSR &&
                            tx.rxPtTestReq_validPattern == 3'h0 &&
                            tx.rxPtTestReq_burstCount == 16'd4096);
    end

    if (tx.rxEyeSweepReq_start) begin
      check_common_rx_params(tx, "DV rxEyeSweepReq",
        tx.rxEyeSweepReq_patternType, tx.rxEyeSweepReq_clockPhase,
        tx.rxEyeSweepReq_dataPattern, tx.rxEyeSweepReq_validPattern,
        tx.rxEyeSweepReq_patternMode, tx.rxEyeSweepReq_iterationCount,
        tx.rxEyeSweepReq_idleCount, tx.rxEyeSweepReq_burstCount,
        tx.rxEyeSweepReq_maxErrorThreshold, tx.rxEyeSweepReq_comparisonMode,
        PAT_LFSR, 3'h1, 3'h0, 16'd4096);
      saw_dv_lfsr_params = (tx.rxEyeSweepReq_patternType == PAT_LFSR &&
                            tx.rxEyeSweepReq_validPattern == 3'h0 &&
                            tx.rxEyeSweepReq_burstCount == 16'd4096);
    end

    if (tx.trainingRespResultsValid && tx.trainingRespResultsBits == 16'hFFFF)
      saw_dv_success = 1;
  endfunction

  function void decode_req_tx(logic [127:0] d);
    if (`MT_OP(d) != `MT_OP_NODATA || `MT_MC(d) != `MT_MC_REQ) return;
    case (`MT_SC(d))
      `MT_SC_VV_START:  saw_vv_start_req = 1;
      `MT_SC_VV_END:    saw_vv_end_req = 1;
      `MT_SC_DV_START:  saw_dv_start_req = 1;
      `MT_SC_DV_END:    saw_dv_end_req = 1;
      `MT_SC_SI_DONE:   saw_si_done_req = 1;
      `MT_SC_TC_DONE:   saw_tc_done_req = 1;
      `MT_SC_RCC_START: saw_rcc_start_req = 1;
      `MT_SC_RCC_DONE:  saw_rcc_done_req = 1;
      `MT_SC_VTC_START: saw_vtc_start_req = 1;
      `MT_SC_VTC_DONE:  saw_vtc_done_req = 1;
      `MT_SC_VTV_START: saw_vtv_start_req = 1;
      `MT_SC_VTV_DONE:  saw_vtv_done_req = 1;
      `MT_SC_DC1_START: saw_dc1_start_req = 1;
      `MT_SC_DC1_END:   saw_dc1_end_req = 1;
      `MT_SC_DTV_START: saw_dtv_start_req = 1;
      `MT_SC_DTV_END:   saw_dtv_end_req = 1;
      `MT_SC_RDS_START: saw_rds_start_req = 1;
      `MT_SC_RDS_END:   saw_rds_end_req = 1;
      `MT_SC_DC2_START: saw_dc2_start_req = 1;
      `MT_SC_DC2_END:   saw_dc2_end_req = 1;
      `MT_SC_LS_START:  saw_ls_start_req = 1;
      `MT_SC_LS_DONE:   saw_ls_done_req = 1;
    endcase
  endfunction

  function void decode_rsp_tx(logic [127:0] d);
    if (`MT_OP(d) != `MT_OP_NODATA || `MT_MC(d) != `MT_MC_RESP) return;
    case (`MT_SC(d))
      `MT_SC_VV_START: saw_vv_start_rsp = 1;
      `MT_SC_VV_END:   saw_vv_end_rsp = 1;
      `MT_SC_DV_START: saw_dv_start_rsp = 1;
      `MT_SC_DV_END:   saw_dv_end_rsp = 1;
      `MT_SC_SI_DONE:  saw_si_done_rsp = 1;
      `MT_SC_TC_DONE:  saw_tc_done_rsp = 1;
      default: ;
    endcase
  endfunction

  function void print_txselfcal_debug_summary();
    if (!debug_txselfcal ||
        (!expect_full_mbtrain && !expect_txselfcal_checks && !saw_state_txselfcal))
      return;

    `uvm_info("MT_SB", $sformatf(
      "TXSELFCAL summary: state_seen=%0b to_rxclkcal=%0b cycles=%0d start=%0b done=%0b req_valid=%0d req_hs=%0d req_match=%0b rsp_valid=%0d rsp_hs=%0d rsp_match=%0b",
      saw_state_txselfcal, tc_saw_to_rxclkcal, tc_cycles,
      tc_saw_start, tc_saw_done,
      tc_req_tx_valid_count, tc_req_tx_handshake_count, tc_saw_req_match,
      tc_rsp_tx_valid_count, tc_rsp_tx_handshake_count, tc_saw_rsp_match), UVM_LOW)

    if (tc_saw_to_rxclkcal && tc_cycles <= 1 && !tc_saw_req_match) begin
      `uvm_info("MT_SB",
        "TXSELFCAL classification hint: DUT advanced from TXSELFCAL to RXCLKCAL before a requester TXSELFCAL_DONE_REQ exchange completed; this points at stale ready/state transition behavior.",
        UVM_LOW)
    end
    else if (!tc_saw_start) begin
      `uvm_info("MT_SB",
        "TXSELFCAL classification hint: txSelfCalStart never asserted; check whether the sequence entered/held TXSELFCAL.",
        UVM_LOW)
    end
    else if (!tc_saw_done) begin
      `uvm_info("MT_SB",
        "TXSELFCAL classification hint: txSelfCalStart asserted but txSelfCalDone never pulsed; check the UVM driver auto-stub.",
        UVM_LOW)
    end
    else if (!tc_saw_req_match && tc_req_tx_valid_count == 0) begin
      `uvm_info("MT_SB",
        "TXSELFCAL classification hint: txSelfCalDone pulsed but requester TX never became valid in TXSELFCAL; this points at DUT state/ready behavior.",
        UVM_LOW)
    end
    else if (!tc_saw_req_match) begin
      `uvm_info("MT_SB",
        "TXSELFCAL classification hint: requester TX was valid in TXSELFCAL but did not match TXSELFCAL_DONE_REQ; compare the DUT encoding against the UVM constants.",
        UVM_LOW)
    end
    else if (!saw_tc_done_req) begin
      `uvm_info("MT_SB",
        "TXSELFCAL classification hint: requester TXSELFCAL_DONE_REQ appeared in the trace but decode did not latch it; check monitor/scoreboard decode.",
        UVM_LOW)
    end
  endfunction

  function void check_phase(uvm_phase phase);
    `uvm_info("MT_SB", $sformatf(
      "Summary: vv_msg=%0b/%0b/%0b/%0b vv_lane=%0b vv_phase=%0b vv_param=%0b vv_success=%0b dv_msg=%0b/%0b/%0b/%0b dv_param=%0b dv_success=%0b state_dv=%0b state_si=%0b state_tc=%0b state_rcc=%0b fsm_done=%0b err=%0b lane_err=%0b param_err=%0b",
      saw_vv_start_req, saw_vv_start_rsp, saw_vv_end_req, saw_vv_end_rsp,
      saw_vv_lane_ctrl, saw_vv_phase_center, saw_vv_valtrain_params, saw_vv_success,
      saw_dv_start_req, saw_dv_start_rsp, saw_dv_end_req, saw_dv_end_rsp,
      saw_dv_lfsr_params, saw_dv_success, saw_state_datavref, saw_state_speedidle,
      saw_state_txselfcal, saw_state_rxclkcal,
      saw_fsm_done, saw_fsm_error, lane_ctrl_error, train_param_error), UVM_LOW)

    print_txselfcal_debug_summary();

    if (expect_valvref_checks) begin
      if (!saw_vv_start_req)       `uvm_error("MT_SB", "VV-START FAILED: requester never sent VALVREF start req")
      if (!saw_vv_start_rsp)       `uvm_error("MT_SB", "VV-START FAILED: responder never sent VALVREF start resp")
      if (!saw_vv_end_req)         `uvm_error("MT_SB", "VV-06 FAILED: requester never sent VALVREF end req")
      if (!saw_vv_end_rsp)         `uvm_error("MT_SB", "VV-06 FAILED: responder never sent VALVREF end resp")
      if (!saw_state_datavref)     `uvm_error("MT_SB", "VV-06 FAILED: did not exit VALVREF to DATAVREF")
      if (!saw_vv_phase_center)    `uvm_error("MT_SB", "VV-01 FAILED: no VALVREF request used center clock phase")
      if (!saw_vv_lane_ctrl)       `uvm_error("MT_SB", "VV-02 FAILED: VALVREF lane controls for Valid sampling/held-low lanes were not observed")
      if (!saw_vv_valtrain_params) `uvm_error("MT_SB", "VV-03 FAILED: no continuous VALTRAIN request with 1024 UI burst was observed")
      if (!saw_vv_success)         `uvm_error("MT_SB", "VV-04 FAILED: no passing VALTRAIN result was observed")
      if (!saw_vv_partner_valtrain)`uvm_error("MT_SB", "VV-01/VV-03 FAILED: partner-side VALTRAIN responder did not start")
    end

    if (expect_datavref_checks) begin
      if (!saw_dv_start_req)       `uvm_error("MT_SB", "DV-START FAILED: requester never sent DATAVREF start req")
      if (!saw_dv_start_rsp)       `uvm_error("MT_SB", "DV-START FAILED: responder never sent DATAVREF start resp")
      if (!saw_dv_end_req)         `uvm_error("MT_SB", "DV-03 FAILED: requester never sent DATAVREF end req")
      if (!saw_dv_end_rsp)         `uvm_error("MT_SB", "DV-03 FAILED: responder never sent DATAVREF end resp")
      if (!saw_state_speedidle)    `uvm_error("MT_SB", "DV-03 FAILED: did not exit DATAVREF to SPEEDIDLE")
      if (!saw_dv_lfsr_params)     `uvm_error("MT_SB", "DV-01 FAILED: no continuous 4K UI LFSR request was observed")
      if (!saw_dv_success)         `uvm_error("MT_SB", "DV-02 FAILED: no passing DATAVREF result was observed")
    end

    if (expect_full_mbtrain) begin
      if (!saw_si_done_req)   `uvm_error("MT_SB","SPEEDIDLE: requester never sent SPEEDIDLE_DONE_REQ")
      if (!saw_tc_done_req)   `uvm_error("MT_SB","TXSELFCAL: requester never sent TXSELFCAL_DONE_REQ")
      if (!saw_rcc_start_req) `uvm_error("MT_SB","RXCLKCAL: requester never sent RXCLKCAL_START_REQ")
      if (!saw_rcc_done_req)  `uvm_error("MT_SB","RXCLKCAL: requester never sent RXCLKCAL_DONE_REQ")
      if (!saw_vtc_start_req) `uvm_error("MT_SB","VALTRAINCENTER: requester never sent START_REQ")
      if (!saw_vtc_done_req)  `uvm_error("MT_SB","VALTRAINCENTER: requester never sent DONE_REQ")
      if (!saw_vtv_start_req) `uvm_error("MT_SB","VALTRAINVREF: requester never sent START_REQ")
      if (!saw_vtv_done_req)  `uvm_error("MT_SB","VALTRAINVREF: requester never sent DONE_REQ")
      if (!saw_dc1_start_req) `uvm_error("MT_SB","DATATRAINCENTER1: requester never sent START_REQ")
      if (!saw_dc1_end_req)   `uvm_error("MT_SB","DATATRAINCENTER1: requester never sent END_REQ")
      if (!saw_dtv_start_req) `uvm_error("MT_SB","DATATRAINVREF: requester never sent START_REQ")
      if (!saw_dtv_end_req)   `uvm_error("MT_SB","DATATRAINVREF: requester never sent END_REQ")
      if (!saw_rds_start_req) `uvm_error("MT_SB","RXDESKEW: requester never sent START_REQ")
      if (!saw_rds_end_req)   `uvm_error("MT_SB","RXDESKEW: requester never sent END_REQ")
      if (!saw_dc2_start_req) `uvm_error("MT_SB","DATATRAINCENTER2: requester never sent START_REQ")
      if (!saw_dc2_end_req)   `uvm_error("MT_SB","DATATRAINCENTER2: requester never sent END_REQ")
      if (!saw_ls_start_req)  `uvm_error("MT_SB","LINKSPEED: requester never sent LINKSPEED_START_REQ")
      if (!saw_ls_done_req)   `uvm_error("MT_SB","LINKSPEED: requester never sent LINKSPEED_DONE_REQ")
    end

    if (expect_txselfcal_checks) begin
      if (!saw_state_txselfcal) `uvm_error("MT_SB","TXSELFCAL probe: TXSELFCAL state was never observed")
      if (!tc_saw_start)       `uvm_error("MT_SB","TXSELFCAL probe: txSelfCalStart never asserted")
      if (!tc_saw_done)        `uvm_error("MT_SB","TXSELFCAL probe: txSelfCalDone never pulsed")
      if (!saw_tc_done_req)    `uvm_error("MT_SB","TXSELFCAL probe: requester never sent TXSELFCAL_DONE_REQ")
    end
    if (expect_rxclkcal_checks) begin
      if (!saw_state_rxclkcal)  `uvm_error("MT_SB","RXCLKCAL probe: RXCLKCAL state was never observed")
      if (!saw_rcc_start_req)   `uvm_error("MT_SB","RXCLKCAL probe: requester never sent RXCLKCAL_START_REQ")
      if (!saw_rcc_done_req)    `uvm_error("MT_SB","RXCLKCAL probe: requester never sent RXCLKCAL_DONE_REQ")
    end

    if (lane_ctrl_error)
      `uvm_error("MT_SB","XC-05 FAILED: mbLaneCtrlIo mismatches detected")
    if (train_param_error)
      `uvm_error("MT_SB","MBTRAIN training parameter checks failed")
    if (expect_fsm_done && !saw_fsm_done)
      `uvm_error("MT_SB","MBTRAIN FAILED: fsmCtrl_done never asserted")
    if (expect_fsm_error && !saw_fsm_error)
      `uvm_error("MT_SB","Expected fsmCtrl_error but it never asserted")
    if (!expect_fsm_error && saw_fsm_error)
      `uvm_error("MT_SB","Unexpected fsmCtrl_error on success-path test")
  endfunction

endclass
`endif
