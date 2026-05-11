`ifndef MBTRAIN_SCOREBOARD_SV
`define MBTRAIN_SCOREBOARD_SV

// SB field extraction (opcode[4:0], msgCode[21:14], msgSubcode[39:32])
`define MT_OP(d)  d[4:0]
`define MT_MC(d)  d[21:14]
`define MT_SC(d)  d[39:32]

// MBTrain opcode (MessageWithoutData only — all MBTrain msgs are no-data)
`define MT_OP_NODATA 5'h12

// MBTrain msgCode conventions
`define MT_MC_REQ  8'hB5
`define MT_MC_RESP 8'hBA

// msgSubcodes per UCIe spec / SidebandMessageEncodings.scala
`define MT_SC_VV_START  8'h00   // VALVREF_START
`define MT_SC_VV_END    8'h01   // VALVREF_END
`define MT_SC_DV_START  8'h02   // DATAVREF_START
`define MT_SC_DV_END    8'h03   // DATAVREF_END
`define MT_SC_SI_DONE   8'h04   // SPEEDIDLE_DONE
`define MT_SC_TC_DONE   8'h05   // TXSELFCAL_DONE
`define MT_SC_RCC_START 8'h06   // RXCLKCAL_START
`define MT_SC_RCC_DONE  8'h07   // RXCLKCAL_DONE
`define MT_SC_VTC_START 8'h08   // VALTRAINCENTER_START
`define MT_SC_VTC_DONE  8'h09   // VALTRAINCENTER_DONE
`define MT_SC_VTV_START 8'h0A   // VALTRAINVREF_START
`define MT_SC_VTV_DONE  8'h0B   // VALTRAINVREF_DONE
`define MT_SC_DC1_START 8'h0C   // DATATRAINCENTER1_START
`define MT_SC_DC1_END   8'h0D   // DATATRAINCENTER1_END
`define MT_SC_DTV_START 8'h0E   // DATATRAINVREF_START
`define MT_SC_DTV_END   8'h10   // DATATRAINVREF_END
`define MT_SC_RDS_START 8'h11   // RXDESKEW_START
`define MT_SC_RDS_END   8'h12   // RXDESKEW_END
`define MT_SC_DC2_START 8'h13   // DATATRAINCENTER2_START
`define MT_SC_DC2_END   8'h14   // DATATRAINCENTER2_END
`define MT_SC_LS_START  8'h15   // LINKSPEED_START
`define MT_SC_LS_DONE   8'h19   // LINKSPEED_DONE

class mbtrain_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(mbtrain_scoreboard)

  uvm_analysis_export #(mbtrain_transaction) item_collected_export;
  uvm_tlm_analysis_fifo #(mbtrain_transaction) item_collected_fifo;

  // ---- VALVREF (VV) ----
  bit saw_vv_start_req, saw_vv_start_rsp;
  bit saw_vv_end_req,   saw_vv_end_rsp;

  // ---- DATAVREF (DV) ----
  bit saw_dv_start_req, saw_dv_start_rsp;
  bit saw_dv_end_req,   saw_dv_end_rsp;

  // ---- SPEEDIDLE (SI) ----
  bit saw_si_done_req,  saw_si_done_rsp;

  // ---- TXSELFCAL (TC) ----
  bit saw_tc_done_req,  saw_tc_done_rsp;

  // ---- RXCLKCAL (RCC) ----
  bit saw_rcc_start_req, saw_rcc_start_rsp;
  bit saw_rcc_done_req,  saw_rcc_done_rsp;

  // ---- VALTRAINCENTER (VTC) ----
  bit saw_vtc_start_req, saw_vtc_start_rsp;
  bit saw_vtc_done_req,  saw_vtc_done_rsp;

  // ---- VALTRAINVREF (VTV) ----
  bit saw_vtv_start_req, saw_vtv_start_rsp;
  bit saw_vtv_done_req,  saw_vtv_done_rsp;

  // ---- DATATRAINCENTER1 (DC1) ----
  bit saw_dc1_start_req, saw_dc1_start_rsp;
  bit saw_dc1_end_req,   saw_dc1_end_rsp;

  // ---- DATATRAINVREF (DTV) ----
  bit saw_dtv_start_req, saw_dtv_start_rsp;
  bit saw_dtv_end_req,   saw_dtv_end_rsp;

  // ---- RXDESKEW (RDS) ----
  bit saw_rds_start_req, saw_rds_start_rsp;
  bit saw_rds_end_req,   saw_rds_end_rsp;

  // ---- DATATRAINCENTER2 (DC2) ----
  bit saw_dc2_start_req, saw_dc2_start_rsp;
  bit saw_dc2_end_req,   saw_dc2_end_rsp;

  // ---- LINKSPEED (LS) ----
  bit saw_ls_start_req, saw_ls_start_rsp;
  bit saw_ls_done_req,  saw_ls_done_rsp;

  // ---- Lane control (XC-05) ----
  bit lane_ctrl_error;

  // State encoding (matches MBTrainRequester currentState)
  localparam logic [3:0] MT_ST_VALVREF         = 4'h0;
  localparam logic [3:0] MT_ST_DATAVREF        = 4'h1;
  localparam logic [3:0] MT_ST_SPEEDIDLE       = 4'h2;
  localparam logic [3:0] MT_ST_TXSELFCAL       = 4'h3;
  localparam logic [3:0] MT_ST_RXCLKCAL        = 4'h4;
  localparam logic [3:0] MT_ST_VALTRAINCENTER  = 4'h5;
  localparam logic [3:0] MT_ST_VALTRAINVREF    = 4'h6;
  localparam logic [3:0] MT_ST_DATATRAINCENTER1= 4'h7;
  localparam logic [3:0] MT_ST_DATATRAINVREF   = 4'h8;
  localparam logic [3:0] MT_ST_RXDESKEW        = 4'h9;
  localparam logic [3:0] MT_ST_DATATRAINCENTER2= 4'hA;
  localparam logic [3:0] MT_ST_LINKSPEED       = 4'hB;

  // ---- Terminal ----
  bit saw_fsm_done;
  bit saw_fsm_error;

  // Settable by test to adjust end-of-test checks
  bit expect_fsm_done  = 1;
  bit expect_fsm_error = 0;

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

  task run_phase(uvm_phase phase);
    mbtrain_transaction tx;
    forever begin
      item_collected_fifo.get(tx);

      if (tx.tx_valid)     decode_req_tx(tx.tx_data);
      if (tx.rsp_tx_valid) decode_rsp_tx(tx.rsp_tx_data);

      check_lane_ctrl(tx);

      if (tx.fsm_done && !saw_fsm_done) begin
        `uvm_info("MT_SB", "MBTRAIN fsmCtrl_done asserted", UVM_LOW)
        saw_fsm_done = 1;
      end
      if (tx.fsm_error && !saw_fsm_error) begin
        `uvm_info("MT_SB", "MBTRAIN fsmCtrl_error asserted", UVM_LOW)
        saw_fsm_error = 1;
      end
    end
  endtask

  // XC-05: per-state lane control check derived from MBTrainRequester RTL.
  // Expected values per state (all lanes uniform — txDataTriState/rxDataEn are 16-bit):
  //   States 0-2 (VV/DV/SI):  tx_tri=0  rxData=1 rxClk=1 rxValid=1 rxTrack=0
  //   State  3   (TC):        tx_tri=1  rxData=0 rxClk=0 rxValid=0 rxTrack=0
  //   State  4   (RCC):       tx_tri=0  rxData=0 rxClk=1 rxValid=0 rxTrack=1
  //   States 5-8 (VTC/VTV/DC1/DTV): tx_tri=0 rxData=1 rxClk=1 rxValid=1 rxTrack=0
  //   State  9   (RDS):       tx_tri=0  rxData=0 rxClk=1 rxValid=0 rxTrack=1
  //   States A-B (DC2/LS):    tx_tri=0  rxData=1 rxClk=1 rxValid=1 rxTrack=0
  function void check_lane_ctrl(mbtrain_transaction tx);
    logic exp_tx_tri;
    logic exp_rx_data;
    logic exp_rx_clk;
    logic exp_rx_valid;
    logic exp_rx_track;
    string state_name;

    case (tx.currentState)
      MT_ST_VALVREF:          begin state_name="VALVREF";          exp_tx_tri=0; exp_rx_data=1; exp_rx_clk=1; exp_rx_valid=1; exp_rx_track=0; end
      MT_ST_DATAVREF:         begin state_name="DATAVREF";         exp_tx_tri=0; exp_rx_data=1; exp_rx_clk=1; exp_rx_valid=1; exp_rx_track=0; end
      MT_ST_SPEEDIDLE:        begin state_name="SPEEDIDLE";        exp_tx_tri=0; exp_rx_data=1; exp_rx_clk=1; exp_rx_valid=1; exp_rx_track=0; end
      MT_ST_TXSELFCAL:        begin state_name="TXSELFCAL";        exp_tx_tri=1; exp_rx_data=0; exp_rx_clk=0; exp_rx_valid=0; exp_rx_track=0; end
      MT_ST_RXCLKCAL:         begin state_name="RXCLKCAL";         exp_tx_tri=0; exp_rx_data=0; exp_rx_clk=1; exp_rx_valid=0; exp_rx_track=1; end
      MT_ST_VALTRAINCENTER:   begin state_name="VALTRAINCENTER";   exp_tx_tri=0; exp_rx_data=1; exp_rx_clk=1; exp_rx_valid=1; exp_rx_track=0; end
      MT_ST_VALTRAINVREF:     begin state_name="VALTRAINVREF";     exp_tx_tri=0; exp_rx_data=1; exp_rx_clk=1; exp_rx_valid=1; exp_rx_track=0; end
      MT_ST_DATATRAINCENTER1: begin state_name="DATATRAINCENTER1"; exp_tx_tri=0; exp_rx_data=1; exp_rx_clk=1; exp_rx_valid=1; exp_rx_track=0; end
      MT_ST_DATATRAINVREF:    begin state_name="DATATRAINVREF";    exp_tx_tri=0; exp_rx_data=1; exp_rx_clk=1; exp_rx_valid=1; exp_rx_track=0; end
      MT_ST_RXDESKEW:         begin state_name="RXDESKEW";         exp_tx_tri=0; exp_rx_data=0; exp_rx_clk=1; exp_rx_valid=0; exp_rx_track=1; end
      MT_ST_DATATRAINCENTER2: begin state_name="DATATRAINCENTER2"; exp_tx_tri=0; exp_rx_data=1; exp_rx_clk=1; exp_rx_valid=1; exp_rx_track=0; end
      MT_ST_LINKSPEED:        begin state_name="LINKSPEED";        exp_tx_tri=0; exp_rx_data=1; exp_rx_clk=1; exp_rx_valid=1; exp_rx_track=0; end
      default: return;
    endcase

    if (tx.mbLaneCtrl_txDataTriState  !== {16{exp_tx_tri}}) begin
      `uvm_error("MT_SB", $sformatf("XC-05 [%s] txDataTriState: exp=%04h got=%04h",
        state_name, {16{exp_tx_tri}}, tx.mbLaneCtrl_txDataTriState))
      lane_ctrl_error = 1;
    end
    if (tx.mbLaneCtrl_txClkTriState   !== exp_tx_tri) begin
      `uvm_error("MT_SB", $sformatf("XC-05 [%s] txClkTriState: exp=%0b got=%0b",
        state_name, exp_tx_tri, tx.mbLaneCtrl_txClkTriState))
      lane_ctrl_error = 1;
    end
    if (tx.mbLaneCtrl_txValidTriState !== exp_tx_tri) begin
      `uvm_error("MT_SB", $sformatf("XC-05 [%s] txValidTriState: exp=%0b got=%0b",
        state_name, exp_tx_tri, tx.mbLaneCtrl_txValidTriState))
      lane_ctrl_error = 1;
    end
    if (tx.mbLaneCtrl_txTrackTriState !== exp_tx_tri) begin
      `uvm_error("MT_SB", $sformatf("XC-05 [%s] txTrackTriState: exp=%0b got=%0b",
        state_name, exp_tx_tri, tx.mbLaneCtrl_txTrackTriState))
      lane_ctrl_error = 1;
    end
    if (tx.mbLaneCtrl_rxDataEn  !== {16{exp_rx_data}}) begin
      `uvm_error("MT_SB", $sformatf("XC-05 [%s] rxDataEn: exp=%04h got=%04h",
        state_name, {16{exp_rx_data}}, tx.mbLaneCtrl_rxDataEn))
      lane_ctrl_error = 1;
    end
    if (tx.mbLaneCtrl_rxClkEn   !== exp_rx_clk) begin
      `uvm_error("MT_SB", $sformatf("XC-05 [%s] rxClkEn: exp=%0b got=%0b",
        state_name, exp_rx_clk, tx.mbLaneCtrl_rxClkEn))
      lane_ctrl_error = 1;
    end
    if (tx.mbLaneCtrl_rxValidEn !== exp_rx_valid) begin
      `uvm_error("MT_SB", $sformatf("XC-05 [%s] rxValidEn: exp=%0b got=%0b",
        state_name, exp_rx_valid, tx.mbLaneCtrl_rxValidEn))
      lane_ctrl_error = 1;
    end
    if (tx.mbLaneCtrl_rxTrackEn !== exp_rx_track) begin
      `uvm_error("MT_SB", $sformatf("XC-05 [%s] rxTrackEn: exp=%0b got=%0b",
        state_name, exp_rx_track, tx.mbLaneCtrl_rxTrackEn))
      lane_ctrl_error = 1;
    end
  endfunction

  function void decode_req_tx(logic [127:0] d);
    if (`MT_OP(d) != `MT_OP_NODATA || `MT_MC(d) != `MT_MC_REQ) return;
    case (`MT_SC(d))
      `MT_SC_VV_START:  if (!saw_vv_start_req)  begin `uvm_info("MT_SB","VV: req sent VALVREF_START_REQ",   UVM_LOW) saw_vv_start_req  = 1; end
      `MT_SC_VV_END:    if (!saw_vv_end_req)    begin `uvm_info("MT_SB","VV: req sent VALVREF_END_REQ",     UVM_LOW) saw_vv_end_req    = 1; end
      `MT_SC_DV_START:  if (!saw_dv_start_req)  begin `uvm_info("MT_SB","DV: req sent DATAVREF_START_REQ",  UVM_LOW) saw_dv_start_req  = 1; end
      `MT_SC_DV_END:    if (!saw_dv_end_req)    begin `uvm_info("MT_SB","DV: req sent DATAVREF_END_REQ",    UVM_LOW) saw_dv_end_req    = 1; end
      `MT_SC_SI_DONE:   if (!saw_si_done_req)   begin `uvm_info("MT_SB","SI: req sent SPEEDIDLE_DONE_REQ",  UVM_LOW) saw_si_done_req   = 1; end
      `MT_SC_TC_DONE:   if (!saw_tc_done_req)   begin `uvm_info("MT_SB","TC: req sent TXSELFCAL_DONE_REQ",  UVM_LOW) saw_tc_done_req   = 1; end
      `MT_SC_RCC_START: if (!saw_rcc_start_req) begin `uvm_info("MT_SB","RCC: req sent RXCLKCAL_START_REQ", UVM_LOW) saw_rcc_start_req = 1; end
      `MT_SC_RCC_DONE:  if (!saw_rcc_done_req)  begin `uvm_info("MT_SB","RCC: req sent RXCLKCAL_DONE_REQ",  UVM_LOW) saw_rcc_done_req  = 1; end
      `MT_SC_VTC_START: if (!saw_vtc_start_req) begin `uvm_info("MT_SB","VTC: req sent VALTRAINCENTER_START_REQ", UVM_LOW) saw_vtc_start_req = 1; end
      `MT_SC_VTC_DONE:  if (!saw_vtc_done_req)  begin `uvm_info("MT_SB","VTC: req sent VALTRAINCENTER_DONE_REQ",  UVM_LOW) saw_vtc_done_req  = 1; end
      `MT_SC_VTV_START: if (!saw_vtv_start_req) begin `uvm_info("MT_SB","VTV: req sent VALTRAINVREF_START_REQ",   UVM_LOW) saw_vtv_start_req = 1; end
      `MT_SC_VTV_DONE:  if (!saw_vtv_done_req)  begin `uvm_info("MT_SB","VTV: req sent VALTRAINVREF_DONE_REQ",    UVM_LOW) saw_vtv_done_req  = 1; end
      `MT_SC_DC1_START: if (!saw_dc1_start_req) begin `uvm_info("MT_SB","DC1: req sent DATATRAINCENTER1_START_REQ", UVM_LOW) saw_dc1_start_req = 1; end
      `MT_SC_DC1_END:   if (!saw_dc1_end_req)   begin `uvm_info("MT_SB","DC1: req sent DATATRAINCENTER1_END_REQ",   UVM_LOW) saw_dc1_end_req   = 1; end
      `MT_SC_DTV_START: if (!saw_dtv_start_req) begin `uvm_info("MT_SB","DTV: req sent DATATRAINVREF_START_REQ",   UVM_LOW) saw_dtv_start_req = 1; end
      `MT_SC_DTV_END:   if (!saw_dtv_end_req)   begin `uvm_info("MT_SB","DTV: req sent DATATRAINVREF_END_REQ",     UVM_LOW) saw_dtv_end_req   = 1; end
      `MT_SC_RDS_START: if (!saw_rds_start_req) begin `uvm_info("MT_SB","RDS: req sent RXDESKEW_START_REQ", UVM_LOW) saw_rds_start_req = 1; end
      `MT_SC_RDS_END:   if (!saw_rds_end_req)   begin `uvm_info("MT_SB","RDS: req sent RXDESKEW_END_REQ",   UVM_LOW) saw_rds_end_req   = 1; end
      `MT_SC_DC2_START: if (!saw_dc2_start_req) begin `uvm_info("MT_SB","DC2: req sent DATATRAINCENTER2_START_REQ", UVM_LOW) saw_dc2_start_req = 1; end
      `MT_SC_DC2_END:   if (!saw_dc2_end_req)   begin `uvm_info("MT_SB","DC2: req sent DATATRAINCENTER2_END_REQ",   UVM_LOW) saw_dc2_end_req   = 1; end
      `MT_SC_LS_START:  if (!saw_ls_start_req)  begin `uvm_info("MT_SB","LS: req sent LINKSPEED_START_REQ",  UVM_LOW) saw_ls_start_req  = 1; end
      `MT_SC_LS_DONE:   if (!saw_ls_done_req)   begin `uvm_info("MT_SB","LS: req sent LINKSPEED_DONE_REQ",   UVM_LOW) saw_ls_done_req   = 1; end
    endcase
  endfunction

  function void decode_rsp_tx(logic [127:0] d);
    if (`MT_OP(d) != `MT_OP_NODATA || `MT_MC(d) != `MT_MC_RESP) return;
    case (`MT_SC(d))
      `MT_SC_VV_START:  if (!saw_vv_start_rsp)  begin `uvm_info("MT_SB","VV: rsp sent VALVREF_START_RESP",   UVM_LOW) saw_vv_start_rsp  = 1; end
      `MT_SC_VV_END:    if (!saw_vv_end_rsp)    begin `uvm_info("MT_SB","VV: rsp sent VALVREF_END_RESP",     UVM_LOW) saw_vv_end_rsp    = 1; end
      `MT_SC_DV_START:  if (!saw_dv_start_rsp)  begin `uvm_info("MT_SB","DV: rsp sent DATAVREF_START_RESP",  UVM_LOW) saw_dv_start_rsp  = 1; end
      `MT_SC_DV_END:    if (!saw_dv_end_rsp)    begin `uvm_info("MT_SB","DV: rsp sent DATAVREF_END_RESP",    UVM_LOW) saw_dv_end_rsp    = 1; end
      `MT_SC_SI_DONE:   if (!saw_si_done_rsp)   begin `uvm_info("MT_SB","SI: rsp sent SPEEDIDLE_DONE_RESP",  UVM_LOW) saw_si_done_rsp   = 1; end
      `MT_SC_TC_DONE:   if (!saw_tc_done_rsp)   begin `uvm_info("MT_SB","TC: rsp sent TXSELFCAL_DONE_RESP",  UVM_LOW) saw_tc_done_rsp   = 1; end
      `MT_SC_RCC_START: if (!saw_rcc_start_rsp) begin `uvm_info("MT_SB","RCC: rsp sent RXCLKCAL_START_RESP", UVM_LOW) saw_rcc_start_rsp = 1; end
      `MT_SC_RCC_DONE:  if (!saw_rcc_done_rsp)  begin `uvm_info("MT_SB","RCC: rsp sent RXCLKCAL_DONE_RESP",  UVM_LOW) saw_rcc_done_rsp  = 1; end
      `MT_SC_VTC_START: if (!saw_vtc_start_rsp) begin `uvm_info("MT_SB","VTC: rsp sent VALTRAINCENTER_START_RESP", UVM_LOW) saw_vtc_start_rsp = 1; end
      `MT_SC_VTC_DONE:  if (!saw_vtc_done_rsp)  begin `uvm_info("MT_SB","VTC: rsp sent VALTRAINCENTER_DONE_RESP",  UVM_LOW) saw_vtc_done_rsp  = 1; end
      `MT_SC_VTV_START: if (!saw_vtv_start_rsp) begin `uvm_info("MT_SB","VTV: rsp sent VALTRAINVREF_START_RESP",   UVM_LOW) saw_vtv_start_rsp = 1; end
      `MT_SC_VTV_DONE:  if (!saw_vtv_done_rsp)  begin `uvm_info("MT_SB","VTV: rsp sent VALTRAINVREF_DONE_RESP",    UVM_LOW) saw_vtv_done_rsp  = 1; end
      `MT_SC_DC1_START: if (!saw_dc1_start_rsp) begin `uvm_info("MT_SB","DC1: rsp sent DATATRAINCENTER1_START_RESP", UVM_LOW) saw_dc1_start_rsp = 1; end
      `MT_SC_DC1_END:   if (!saw_dc1_end_rsp)   begin `uvm_info("MT_SB","DC1: rsp sent DATATRAINCENTER1_END_RESP",   UVM_LOW) saw_dc1_end_rsp   = 1; end
      `MT_SC_DTV_START: if (!saw_dtv_start_rsp) begin `uvm_info("MT_SB","DTV: rsp sent DATATRAINVREF_START_RESP",   UVM_LOW) saw_dtv_start_rsp = 1; end
      `MT_SC_DTV_END:   if (!saw_dtv_end_rsp)   begin `uvm_info("MT_SB","DTV: rsp sent DATATRAINVREF_END_RESP",     UVM_LOW) saw_dtv_end_rsp   = 1; end
      `MT_SC_RDS_START: if (!saw_rds_start_rsp) begin `uvm_info("MT_SB","RDS: rsp sent RXDESKEW_START_RESP", UVM_LOW) saw_rds_start_rsp = 1; end
      `MT_SC_RDS_END:   if (!saw_rds_end_rsp)   begin `uvm_info("MT_SB","RDS: rsp sent RXDESKEW_END_RESP",   UVM_LOW) saw_rds_end_rsp   = 1; end
      `MT_SC_DC2_START: if (!saw_dc2_start_rsp) begin `uvm_info("MT_SB","DC2: rsp sent DATATRAINCENTER2_START_RESP", UVM_LOW) saw_dc2_start_rsp = 1; end
      `MT_SC_DC2_END:   if (!saw_dc2_end_rsp)   begin `uvm_info("MT_SB","DC2: rsp sent DATATRAINCENTER2_END_RESP",   UVM_LOW) saw_dc2_end_rsp   = 1; end
      `MT_SC_LS_START:  if (!saw_ls_start_rsp)  begin `uvm_info("MT_SB","LS: rsp sent LINKSPEED_START_RESP",  UVM_LOW) saw_ls_start_rsp  = 1; end
      `MT_SC_LS_DONE:   if (!saw_ls_done_rsp)   begin `uvm_info("MT_SB","LS: rsp sent LINKSPEED_DONE_RESP",   UVM_LOW) saw_ls_done_rsp   = 1; end
    endcase
  endfunction

  function void check_phase(uvm_phase phase);
    `uvm_info("MT_SB", $sformatf(
      "Summary: vv=%0b/%0b dv=%0b/%0b si=%0b tc=%0b rcc=%0b/%0b vtc=%0b/%0b vtv=%0b/%0b dc1=%0b/%0b dtv=%0b/%0b rds=%0b/%0b dc2=%0b/%0b ls=%0b/%0b fsm_done=%0b err=%0b lane_ctrl_err=%0b",
      saw_vv_start_req,  saw_vv_end_req,
      saw_dv_start_req,  saw_dv_end_req,
      saw_si_done_req,   saw_tc_done_req,
      saw_rcc_start_req, saw_rcc_done_req,
      saw_vtc_start_req, saw_vtc_done_req,
      saw_vtv_start_req, saw_vtv_done_req,
      saw_dc1_start_req, saw_dc1_end_req,
      saw_dtv_start_req, saw_dtv_end_req,
      saw_rds_start_req, saw_rds_end_req,
      saw_dc2_start_req, saw_dc2_end_req,
      saw_ls_start_req,  saw_ls_done_req,
      saw_fsm_done, saw_fsm_error, lane_ctrl_error), UVM_LOW)

    if (expect_fsm_done) begin
      if (!saw_vv_start_req)  `uvm_error("MT_SB","VALVREF: requester never sent VALVREF_START_REQ")
      if (!saw_vv_end_req)    `uvm_error("MT_SB","VALVREF: requester never sent VALVREF_END_REQ")
      if (!saw_dv_start_req)  `uvm_error("MT_SB","DATAVREF: requester never sent DATAVREF_START_REQ")
      if (!saw_dv_end_req)    `uvm_error("MT_SB","DATAVREF: requester never sent DATAVREF_END_REQ")
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
      if (!saw_fsm_done)      `uvm_error("MT_SB","MBTRAIN FAILED: fsmCtrl_done never asserted")
    end

    if (lane_ctrl_error)
      `uvm_error("MT_SB","XC-05 FAILED: mbLaneCtrlIo mismatches detected above (see per-transaction errors)")

    if (expect_fsm_error && !saw_fsm_error)
      `uvm_error("MT_SB","Expected fsmCtrl_error but it never asserted")
    if (!expect_fsm_error && saw_fsm_error && expect_fsm_done)
      `uvm_error("MT_SB","Unexpected fsmCtrl_error on success-path test")
  endfunction

endclass
`endif
