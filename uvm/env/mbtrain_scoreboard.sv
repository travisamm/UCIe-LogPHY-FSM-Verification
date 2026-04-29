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

      // TODO: mbLaneCtrlIo transition checks per spec table (VV-01, DV-01, etc.)

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
      "Summary: vv=%0b/%0b dv=%0b/%0b si=%0b tc=%0b rcc=%0b/%0b vtc=%0b/%0b vtv=%0b/%0b dc1=%0b/%0b dtv=%0b/%0b rds=%0b/%0b dc2=%0b/%0b ls=%0b/%0b fsm_done=%0b err=%0b",
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
      saw_fsm_done, saw_fsm_error), UVM_LOW)

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

    if (expect_fsm_error && !saw_fsm_error)
      `uvm_error("MT_SB","Expected fsmCtrl_error but it never asserted")
    if (!expect_fsm_error && saw_fsm_error && expect_fsm_done)
      `uvm_error("MT_SB","Unexpected fsmCtrl_error on success-path test")
  endfunction

endclass
`endif
