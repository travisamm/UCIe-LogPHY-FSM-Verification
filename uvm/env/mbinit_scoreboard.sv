`ifndef MBINIT_SCOREBOARD_SV
`define MBINIT_SCOREBOARD_SV

// SB field extraction (opcode[4:0], msgCode[21:14], msgSubcode[39:32])
`define MB_OP(d)   d[4:0]
`define MB_MC(d)   d[21:14]
`define MB_SC(d)   d[39:32]

// Opcodes
`define MB_OP_NODATA 5'h12
`define MB_OP_64DATA 5'h1B

// msgCode conventions
`define MB_MC_REQ  8'hA5
`define MB_MC_RESP 8'hAA

// msgSubcodes per vplan
`define MB_SC_PARAM     8'h00
`define MB_SC_CAL       8'h02
`define MB_SC_RCLK_INIT 8'h03
`define MB_SC_RCLK_RES  8'h04
`define MB_SC_RCLK_DONE 8'h08
`define MB_SC_RVAL_INIT 8'h09
`define MB_SC_RVAL_RES  8'h0A
`define MB_SC_RVAL_DONE 8'h0C
`define MB_SC_LR_INIT   8'h0D
`define MB_SC_LR_CLR    8'h0E
`define MB_SC_LR_RES    8'h0F
`define MB_SC_LR_DONE   8'h10
`define MB_SC_RM_START  8'h11
`define MB_SC_RM_END    8'h13
`define MB_SC_RM_APPLY  8'h14

class mbinit_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(mbinit_scoreboard)

  localparam logic [2:0] MB_STATE_PARAM      = 3'd0;
  localparam logic [2:0] MB_STATE_CAL        = 3'd1;
  localparam logic [2:0] MB_STATE_REPAIRCLK  = 3'd2;
  localparam logic [2:0] MB_STATE_REPAIRVAL  = 3'd3;
  localparam logic [2:0] MB_STATE_REVERSALMB = 3'd4;
  localparam logic [2:0] MB_STATE_REPAIRMB   = 3'd5;
  localparam logic [2:0] MB_STATE_TOMBTRAIN  = 3'd6;

  uvm_analysis_export #(mbinit_transaction) item_collected_export;
  uvm_tlm_analysis_fifo #(mbinit_transaction) item_collected_fifo;

  // ---- PARAM (MP-01..04, MP-06) ----
  bit saw_req_tx;          // Any requester sideband TX
  bit saw_rsp_tx;          // Any responder sideband TX
  bit saw_bad_req_tx;      // Requester TX did not match expected SB fields
  bit saw_bad_rsp_tx;      // Responder TX did not match expected SB fields
  bit saw_param_req_tx;    // MP-01: DUT requester sent PARAM_CFG_REQ
  bit saw_param_resp_tx;   // MP-01: DUT responder sent PARAM_CFG_RESP
  bit mp_02_verified;      // MP-02: negotiated max common data rate observed
  bit mp_03_verified;      // MP-03: negotiated clock mode matches request
  bit mp_04_triggered;     // MP-04: interoperableParamsNotFound path

  // ---- State transition coverage for CSV exit requirements ----
  bit saw_state_cal;        // MP-06: PARAM exits to CAL
  bit saw_state_repairclk;  // MC-02: CAL exits to REPAIRCLK
  bit saw_state_repairval;  // RC-05: REPAIRCLK exits to REPAIRVAL
  bit saw_state_reversalmb; // RV-07: REPAIRVAL exits to REVERSALMB
  bit saw_state_repairmb;   // LR-06: REVERSALMB exits to REPAIRMB
  bit saw_state_tombtrain;  // RM-08: REPAIRMB exits toward MBTRAIN

  // ---- CAL (MC-01/02) ----
  bit saw_cal_req_tx;      // MC-01: DUT requester sent CAL_DONE_REQ
  bit saw_cal_resp_tx;     // MC-02: DUT responder sent CAL_DONE_RESP

  // ---- REPAIRCLK flow messages; RC-05 is checked through DONE and state exit ----
  bit saw_rclk_init_req_tx;
  bit saw_rclk_init_resp_tx;
  bit saw_rclk_res_req_tx;
  bit saw_rclk_res_resp_tx;
  bit saw_rclk_done_req_tx;
  bit saw_rclk_done_resp_tx;

  // ---- REPAIRVAL flow messages; RV-07 is checked through DONE and state exit ----
  bit saw_rval_init_req_tx;
  bit saw_rval_init_resp_tx;
  bit saw_rval_res_req_tx;
  bit saw_rval_res_resp_tx;
  bit saw_rval_done_req_tx;
  bit saw_rval_done_resp_tx;

  // ---- REVERSALMB flow messages; LR-01/LR-06 map directly to CSV rows ----
  bit saw_lr_init_req_tx;
  bit saw_lr_init_resp_tx;
  bit saw_lr_res_req_tx;
  bit saw_lr_res_resp_tx;
  bit saw_lr_done_req_tx;
  bit saw_lr_done_resp_tx;

  // ---- REPAIRMB flow messages; RM-08 is checked through END and state exit ----
  bit saw_rm_start_req_tx;
  bit saw_rm_start_resp_tx;
  bit saw_rm_end_req_tx;
  bit saw_rm_end_resp_tx;

  // ---- Terminal ----
  bit saw_fsm_done;
  bit saw_fsm_error;

  // Settable by test to adjust end-of-test checks
  bit expect_param_messages     = 1;
  bit expect_param_common_rate  = 1;
  bit expect_param_negotiation  = 1;
  bit expect_full_mbinit        = 1;
  bit expect_interop_failure    = 0;
  bit expect_fsm_done           = 1;
  bit expect_fsm_error          = 0;

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
    mbinit_transaction tx;
    forever begin
      item_collected_fifo.get(tx);

      // Requester TX (DUT → remote)
      if (tx.tx_valid) begin
        saw_req_tx = 1;
        decode_req_tx(tx.tx_data);
      end
      // Responder TX (DUT → remote)
      if (tx.rsp_tx_valid) begin
        saw_rsp_tx = 1;
        decode_rsp_tx(tx.rsp_tx_data);
      end

      if (tx.currentState == MB_STATE_CAL)
        saw_state_cal = 1;
      if (tx.currentState == MB_STATE_REPAIRCLK)
        saw_state_repairclk = 1;
      if (tx.currentState == MB_STATE_REPAIRVAL)
        saw_state_repairval = 1;
      if (tx.currentState == MB_STATE_REVERSALMB)
        saw_state_reversalmb = 1;
      if (tx.currentState == MB_STATE_REPAIRMB)
        saw_state_repairmb = 1;
      if (tx.currentState == MB_STATE_TOMBTRAIN)
        saw_state_tombtrain = 1;

      if (tx.negotiatedPhySettings_valid) begin
        if (!mp_02_verified && tx.negotiated_maxDataRate == 4'hF) begin
          `uvm_info("MB_SB", "MP-02: negotiated max common data rate observed", UVM_LOW)
          mp_02_verified = 1;
        end
        if (!mp_03_verified && tx.negotiated_clockMode == 1'b1) begin
          `uvm_info("MB_SB", "MP-03: negotiated clock mode matches request", UVM_LOW)
          mp_03_verified = 1;
        end
      end

      // MP-04: interoperable params not found
      if (tx.interoperableParamsNotFound && !mp_04_triggered) begin
        `uvm_info("MB_SB", "MP-04: interoperableParamsNotFound asserted", UVM_LOW)
        mp_04_triggered = 1;
      end

      if (tx.fsm_done && !saw_fsm_done) begin
        `uvm_info("MB_SB", "MBINIT fsmCtrl_done asserted", UVM_LOW)
        saw_fsm_done = 1;
      end
      if (tx.fsm_error && !saw_fsm_error) begin
        `uvm_info("MB_SB", "MBINIT fsmCtrl_error asserted", UVM_LOW)
        saw_fsm_error = 1;
      end
    end
  endtask

  function void decode_req_tx(logic [127:0] d);
    bit decoded;
    decoded = 0;

    // PARAM_CFG_REQ (opcode=0x1B, MC=REQ, SC=0x00)
    if (`MB_OP(d)==`MB_OP_64DATA && `MB_MC(d)==`MB_MC_REQ && `MB_SC(d)==`MB_SC_PARAM) begin
      decoded = 1;
      if (!saw_param_req_tx) begin
        `uvm_info("MB_SB","MP-01: DUT req sent PARAM_CFG_REQ",UVM_LOW)
        saw_param_req_tx = 1; end
    end
    if (`MB_OP(d)==`MB_OP_NODATA && `MB_MC(d)==`MB_MC_REQ) begin
      decoded = 1;
      case (`MB_SC(d))
        `MB_SC_CAL: if (!saw_cal_req_tx) begin
          `uvm_info("MB_SB","MC-01: DUT req sent CAL_DONE_REQ",UVM_LOW)
          saw_cal_req_tx=1; end
        `MB_SC_RCLK_INIT: if (!saw_rclk_init_req_tx) begin
          `uvm_info("MB_SB","REPAIRCLK: DUT req sent REPAIRCLK_INIT_REQ",UVM_LOW)
          saw_rclk_init_req_tx=1; end
        `MB_SC_RCLK_RES: if (!saw_rclk_res_req_tx) begin
          `uvm_info("MB_SB","REPAIRCLK: DUT req sent REPAIRCLK_RESULT_REQ",UVM_LOW)
          saw_rclk_res_req_tx=1; end
        `MB_SC_RCLK_DONE: if (!saw_rclk_done_req_tx) begin
          `uvm_info("MB_SB","RC-05: DUT req sent REPAIRCLK_DONE_REQ",UVM_LOW)
          saw_rclk_done_req_tx=1; end
        `MB_SC_RVAL_INIT: if (!saw_rval_init_req_tx) begin
          `uvm_info("MB_SB","REPAIRVAL: DUT req sent REPAIRVAL_INIT_REQ",UVM_LOW)
          saw_rval_init_req_tx=1; end
        `MB_SC_RVAL_RES: if (!saw_rval_res_req_tx) begin
          `uvm_info("MB_SB","REPAIRVAL: DUT req sent REPAIRVAL_RESULT_REQ",UVM_LOW)
          saw_rval_res_req_tx=1; end
        `MB_SC_RVAL_DONE: if (!saw_rval_done_req_tx) begin
          `uvm_info("MB_SB","RV-07: DUT req sent REPAIRVAL_DONE_REQ",UVM_LOW)
          saw_rval_done_req_tx=1; end
        `MB_SC_LR_INIT: if (!saw_lr_init_req_tx) begin
          `uvm_info("MB_SB","LR-01: DUT req sent REVERSALMB_INIT_REQ",UVM_LOW)
          saw_lr_init_req_tx=1; end
        `MB_SC_LR_RES: if (!saw_lr_res_req_tx) begin
          `uvm_info("MB_SB","REVERSALMB: DUT req sent REVERSALMB_RESULT_REQ",UVM_LOW)
          saw_lr_res_req_tx=1; end
        `MB_SC_LR_DONE: if (!saw_lr_done_req_tx) begin
          `uvm_info("MB_SB","LR-06: DUT req sent REVERSALMB_DONE_REQ",UVM_LOW)
          saw_lr_done_req_tx=1; end
        `MB_SC_RM_START: if (!saw_rm_start_req_tx) begin
          `uvm_info("MB_SB","REPAIRMB: DUT req sent REPAIRMB_START_REQ",UVM_LOW)
          saw_rm_start_req_tx=1; end
        `MB_SC_RM_END: if (!saw_rm_end_req_tx) begin
          `uvm_info("MB_SB","RM-08: DUT req sent REPAIRMB_END_REQ",UVM_LOW)
          saw_rm_end_req_tx=1; end
      endcase
    end

    if (!decoded && !saw_bad_req_tx) begin
      saw_bad_req_tx = 1;
      `uvm_error("MB_SB", $sformatf(
        "Requester TX has invalid MBINIT sideband fields: data=%032h op=%02h msgCode=%02h msgSubcode=%02h",
        d, `MB_OP(d), `MB_MC(d), `MB_SC(d)))
    end
  endfunction

  function void decode_rsp_tx(logic [127:0] d);
    bit decoded;
    decoded = 0;

    // PARAM_CFG_RESP
    if (`MB_OP(d)==`MB_OP_64DATA && `MB_MC(d)==`MB_MC_RESP && `MB_SC(d)==`MB_SC_PARAM) begin
      decoded = 1;
      if (!saw_param_resp_tx) begin
        `uvm_info("MB_SB","MP-01: DUT rsp sent PARAM_CFG_RESP",UVM_LOW)
        saw_param_resp_tx=1; end
    end
    if (`MB_OP(d)==`MB_OP_NODATA && `MB_MC(d)==`MB_MC_RESP) begin
      decoded = 1;
      case (`MB_SC(d))
        `MB_SC_CAL: if (!saw_cal_resp_tx) begin
          `uvm_info("MB_SB","MC-02: DUT rsp sent CAL_DONE_RESP",UVM_LOW)
          saw_cal_resp_tx=1; end
        `MB_SC_RCLK_INIT: if (!saw_rclk_init_resp_tx) begin
          `uvm_info("MB_SB","REPAIRCLK: DUT rsp sent REPAIRCLK_INIT_RESP",UVM_LOW)
          saw_rclk_init_resp_tx=1; end
        `MB_SC_RCLK_RES: if (!saw_rclk_res_resp_tx) begin
          `uvm_info("MB_SB","REPAIRCLK: DUT rsp sent REPAIRCLK_RESULT_RESP",UVM_LOW)
          saw_rclk_res_resp_tx=1; end
        `MB_SC_RCLK_DONE: if (!saw_rclk_done_resp_tx) begin
          `uvm_info("MB_SB","RC-05: DUT rsp sent REPAIRCLK_DONE_RESP",UVM_LOW)
          saw_rclk_done_resp_tx=1; end
        `MB_SC_RVAL_INIT: if (!saw_rval_init_resp_tx) begin
          `uvm_info("MB_SB","REPAIRVAL: DUT rsp sent REPAIRVAL_INIT_RESP",UVM_LOW)
          saw_rval_init_resp_tx=1; end
        `MB_SC_RVAL_RES: if (!saw_rval_res_resp_tx) begin
          `uvm_info("MB_SB","REPAIRVAL: DUT rsp sent REPAIRVAL_RESULT_RESP",UVM_LOW)
          saw_rval_res_resp_tx=1; end
        `MB_SC_RVAL_DONE: if (!saw_rval_done_resp_tx) begin
          `uvm_info("MB_SB","RV-07: DUT rsp sent REPAIRVAL_DONE_RESP",UVM_LOW)
          saw_rval_done_resp_tx=1; end
        `MB_SC_LR_INIT: if (!saw_lr_init_resp_tx) begin
          `uvm_info("MB_SB","LR-01: DUT rsp sent REVERSALMB_INIT_RESP",UVM_LOW)
          saw_lr_init_resp_tx=1; end
        `MB_SC_LR_RES: if (!saw_lr_res_resp_tx) begin
          `uvm_info("MB_SB","REVERSALMB: DUT rsp sent REVERSALMB_RESULT_RESP",UVM_LOW)
          saw_lr_res_resp_tx=1; end
        `MB_SC_LR_DONE: if (!saw_lr_done_resp_tx) begin
          `uvm_info("MB_SB","LR-06: DUT rsp sent REVERSALMB_DONE_RESP",UVM_LOW)
          saw_lr_done_resp_tx=1; end
        `MB_SC_RM_START: if (!saw_rm_start_resp_tx) begin
          `uvm_info("MB_SB","REPAIRMB: DUT rsp sent REPAIRMB_START_RESP",UVM_LOW)
          saw_rm_start_resp_tx=1; end
        `MB_SC_RM_END: if (!saw_rm_end_resp_tx) begin
          `uvm_info("MB_SB","RM-08: DUT rsp sent REPAIRMB_END_RESP",UVM_LOW)
          saw_rm_end_resp_tx=1; end
      endcase
    end

    if (!decoded && !saw_bad_rsp_tx) begin
      saw_bad_rsp_tx = 1;
      `uvm_error("MB_SB", $sformatf(
        "Responder TX has invalid MBINIT sideband fields: data=%032h op=%02h msgCode=%02h msgSubcode=%02h",
        d, `MB_OP(d), `MB_MC(d), `MB_SC(d)))
    end
  endfunction

  function void check_phase(uvm_phase phase);
    `uvm_info("MB_SB", $sformatf(
      "Summary: req_tx=%0b rsp_tx=%0b bad_req=%0b bad_rsp=%0b param_req=%0b param_resp=%0b mp02=%0b mp03=%0b cal=%0b fsm_done=%0b fsm_err=%0b",
      saw_req_tx, saw_rsp_tx, saw_bad_req_tx, saw_bad_rsp_tx,
      saw_param_req_tx, saw_param_resp_tx, mp_02_verified, mp_03_verified,
      saw_cal_req_tx, saw_fsm_done, saw_fsm_error), UVM_LOW)

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
    end

    if (expect_fsm_done && !saw_fsm_done)
      `uvm_error("MB_SB","MBINIT FAILED: fsmCtrl_done never asserted")

    if (expect_fsm_error && !saw_fsm_error)
      `uvm_error("MB_SB","Expected fsmCtrl_error but it never asserted")
    if (!expect_fsm_error && saw_fsm_error)
      `uvm_error("MB_SB","Unexpected fsmCtrl_error on success-path test")
  endfunction

endclass
`endif
