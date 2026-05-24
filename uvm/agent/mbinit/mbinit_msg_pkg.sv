`ifndef MBINIT_MSG_PKG_SV
`define MBINIT_MSG_PKG_SV

// ===========================================================================
// mbinit_msg_pkg  (Pass 1: MBINIT sideband wire-format helpers)
// ---------------------------------------------------------------------------
// Typed, named replacement for the raw 128-bit `define constants scattered in
// seq/mbinit/mbinit_seq.sv and the bit-slice macros in the legacy scoreboard.
// This is the on-the-wire MBINIT sideband message format only - no UVM types,
// so the pure wire-format vocabulary can be imported anywhere (sequences,
// scoreboard, predictor) without pulling in the event/observation model.
//
// Field layout (SBMsgCompare in SidebandMessageExchanger.scala; identical to
// the bytes the legacy scoreboard decodes and the seq constants encode):
//   opcode      [4:0]
//   msgCode     [21:14]   (REQ 0xA5 / RESP 0xAA)
//   msgSubcode  [39:32]
//   msgInfo     [42:40]   (success/fail nibble on RESULT responses)
//   data        [127:64]  (64-bit payload, present on 64DATA messages)
//
// Unlike SBINIT (which can emit a second "create" layout with a widened
// opcode), MBINIT messages observed today all use this single spec layout, so
// this package models only it. If a create-style layout ever appears, add it
// here rather than in consumers.
// ===========================================================================

package mbinit_msg_pkg;

  // ---- Opcodes ----
  localparam bit [4:0] MBINIT_OP_NODATA = 5'h12;  // message without data
  localparam bit [4:0] MBINIT_OP_64DATA = 5'h1B;  // message with 64-bit data

  // ---- Message codes ----
  localparam bit [7:0] MBINIT_MC_REQ  = 8'hA5;
  localparam bit [7:0] MBINIT_MC_RESP = 8'hAA;

  // ---- Message subcodes (one per MBINIT sub-state exchange) ----
  localparam bit [7:0] MBINIT_SC_PARAM     = 8'h00;
  localparam bit [7:0] MBINIT_SC_CAL       = 8'h02;
  localparam bit [7:0] MBINIT_SC_RCLK_INIT = 8'h03;
  localparam bit [7:0] MBINIT_SC_RCLK_RES  = 8'h04;
  localparam bit [7:0] MBINIT_SC_RCLK_DONE = 8'h08;
  localparam bit [7:0] MBINIT_SC_RVAL_INIT = 8'h09;
  localparam bit [7:0] MBINIT_SC_RVAL_RES  = 8'h0A;
  localparam bit [7:0] MBINIT_SC_RVAL_DONE = 8'h0C;
  localparam bit [7:0] MBINIT_SC_LR_INIT   = 8'h0D;
  localparam bit [7:0] MBINIT_SC_LR_CLR    = 8'h0E;
  localparam bit [7:0] MBINIT_SC_LR_RES    = 8'h0F;
  localparam bit [7:0] MBINIT_SC_LR_DONE   = 8'h10;
  localparam bit [7:0] MBINIT_SC_RM_START  = 8'h11;
  localparam bit [7:0] MBINIT_SC_RM_END    = 8'h13;
  localparam bit [7:0] MBINIT_SC_RM_APPLY  = 8'h14;  // REPAIRMB apply/degrade

  // ---- msgInfo success encodings (RESULT responses) ----
  // RCLK RESULT: repairClkSuccess = msgInfo[2] & msgInfo[1] & msgInfo[0] -> 0x7.
  // RVAL RESULT: repairValSuccess = msgInfo[0]                           -> 0x1.
  localparam bit [2:0] MBINIT_INFO_RCLK_SUCCESS = 3'h7;
  localparam bit [2:0] MBINIT_INFO_RVAL_SUCCESS = 3'h1;
  localparam bit [2:0] MBINIT_INFO_FAIL         = 3'h0;

  // ---- Canonical PARAM payload used by the existing happy-path tests ----
  // data[3:0]=maxDataRate(0xF), data[9]=clockMode(1); other bits carry
  // voltageSwing/feature fields the negotiated-settings decode treats opaquely.
  localparam bit [63:0] MBINIT_PARAM_DATA_DEFAULT = 64'h0000_0000_0000_23FF;
  // LR RESULT success: data popcount > 8 (reversalMbSuccess); fail = 0.
  localparam bit [63:0] MBINIT_LR_DATA_SUCCESS = 64'h0000_0000_0000_FFFF;
  localparam bit [63:0] MBINIT_LR_DATA_FAIL    = 64'h0000_0000_0000_0000;

  // ---- Field accessors -----------------------------------------------------
  function automatic bit [4:0]  mb_op  (logic [127:0] d); return d[4:0];   endfunction
  function automatic bit [7:0]  mb_mc  (logic [127:0] d); return d[21:14]; endfunction
  function automatic bit [7:0]  mb_sc  (logic [127:0] d); return d[39:32]; endfunction
  function automatic bit [2:0]  mb_info(logic [127:0] d); return d[42:40]; endfunction
  function automatic bit [63:0] mb_data(logic [127:0] d); return d[127:64];endfunction

  // True iff d matches the given opcode/msgCode/subcode triple.
  function automatic bit is_mb_msg(logic [127:0] d,
                                   bit [4:0] op,
                                   bit [7:0] mc,
                                   bit [7:0] sc);
    return (d[4:0] == op) && (d[21:14] == mc) && (d[39:32] == sc);
  endfunction

  // ---- Builders ------------------------------------------------------------
  // No-data (opcode 0x12) message with optional msgInfo nibble.
  function automatic logic [127:0] mb_no_data(bit [7:0] mc,
                                              bit [7:0] sc,
                                              bit [2:0] info = 3'h0);
    logic [127:0] r;
    r          = 128'h0;
    r[4:0]     = MBINIT_OP_NODATA;
    r[21:14]   = mc;
    r[39:32]   = sc;
    r[42:40]   = info;
    return r;
  endfunction

  // 64-bit-data (opcode 0x1B) message.
  function automatic logic [127:0] mb_data_msg(bit [7:0]  mc,
                                               bit [7:0]  sc,
                                               logic [63:0] data);
    logic [127:0] r;
    r          = 128'h0;
    r[4:0]     = MBINIT_OP_64DATA;
    r[21:14]   = mc;
    r[39:32]   = sc;
    r[127:64]  = data;
    return r;
  endfunction

  // PARAM payload helper: set the two confirmed-decoded fields. Remaining bits
  // (voltageSwing/features) default to the canonical 0x23FF pattern so the
  // result matches the working tests unless overridden field-by-field.
  function automatic logic [63:0] mb_param_payload(bit [3:0] max_data_rate,
                                                   bit       clock_mode);
    logic [63:0] p;
    p       = MBINIT_PARAM_DATA_DEFAULT;
    p[3:0]  = max_data_rate;
    p[9]    = clock_mode;
    return p;
  endfunction

  // ---- Named convenience builders (reproduce the seq constants exactly) -----
  function automatic logic [127:0] mb_param_req (logic [63:0] data = MBINIT_PARAM_DATA_DEFAULT);
    return mb_data_msg(MBINIT_MC_REQ,  MBINIT_SC_PARAM, data);
  endfunction
  function automatic logic [127:0] mb_param_resp(logic [63:0] data = MBINIT_PARAM_DATA_DEFAULT);
    return mb_data_msg(MBINIT_MC_RESP, MBINIT_SC_PARAM, data);
  endfunction

  function automatic logic [127:0] mb_cal_req ();  return mb_no_data(MBINIT_MC_REQ,  MBINIT_SC_CAL); endfunction
  function automatic logic [127:0] mb_cal_resp();  return mb_no_data(MBINIT_MC_RESP, MBINIT_SC_CAL); endfunction

  function automatic logic [127:0] mb_rclk_init_req (); return mb_no_data(MBINIT_MC_REQ,  MBINIT_SC_RCLK_INIT); endfunction
  function automatic logic [127:0] mb_rclk_init_resp(); return mb_no_data(MBINIT_MC_RESP, MBINIT_SC_RCLK_INIT); endfunction
  function automatic logic [127:0] mb_rclk_res_req  (); return mb_no_data(MBINIT_MC_REQ,  MBINIT_SC_RCLK_RES);  endfunction
  // success=1 -> msgInfo 0x7 (repairClkSuccess); success=0 -> 0x0 (RC-03 fail path).
  function automatic logic [127:0] mb_rclk_res_resp (bit success = 1);
    return mb_no_data(MBINIT_MC_RESP, MBINIT_SC_RCLK_RES,
                      success ? MBINIT_INFO_RCLK_SUCCESS : MBINIT_INFO_FAIL);
  endfunction
  function automatic logic [127:0] mb_rclk_done_req (); return mb_no_data(MBINIT_MC_REQ,  MBINIT_SC_RCLK_DONE); endfunction
  function automatic logic [127:0] mb_rclk_done_resp(); return mb_no_data(MBINIT_MC_RESP, MBINIT_SC_RCLK_DONE); endfunction

  function automatic logic [127:0] mb_rval_init_req (); return mb_no_data(MBINIT_MC_REQ,  MBINIT_SC_RVAL_INIT); endfunction
  function automatic logic [127:0] mb_rval_init_resp(); return mb_no_data(MBINIT_MC_RESP, MBINIT_SC_RVAL_INIT); endfunction
  function automatic logic [127:0] mb_rval_res_req  (); return mb_no_data(MBINIT_MC_REQ,  MBINIT_SC_RVAL_RES);  endfunction
  // success=1 -> msgInfo 0x1 (repairValSuccess); success=0 -> 0x0 (RV-06 fail path).
  function automatic logic [127:0] mb_rval_res_resp (bit success = 1);
    return mb_no_data(MBINIT_MC_RESP, MBINIT_SC_RVAL_RES,
                      success ? MBINIT_INFO_RVAL_SUCCESS : MBINIT_INFO_FAIL);
  endfunction
  function automatic logic [127:0] mb_rval_done_req (); return mb_no_data(MBINIT_MC_REQ,  MBINIT_SC_RVAL_DONE); endfunction
  function automatic logic [127:0] mb_rval_done_resp(); return mb_no_data(MBINIT_MC_RESP, MBINIT_SC_RVAL_DONE); endfunction

  function automatic logic [127:0] mb_lr_init_req (); return mb_no_data(MBINIT_MC_REQ,  MBINIT_SC_LR_INIT); endfunction
  function automatic logic [127:0] mb_lr_init_resp(); return mb_no_data(MBINIT_MC_RESP, MBINIT_SC_LR_INIT); endfunction
  function automatic logic [127:0] mb_lr_clr_req  (); return mb_no_data(MBINIT_MC_REQ,  MBINIT_SC_LR_CLR);  endfunction
  function automatic logic [127:0] mb_lr_clr_resp (); return mb_no_data(MBINIT_MC_RESP, MBINIT_SC_LR_CLR);  endfunction
  function automatic logic [127:0] mb_lr_res_req  (); return mb_no_data(MBINIT_MC_REQ,  MBINIT_SC_LR_RES);  endfunction
  // LR RESULT response is a 64DATA message; success encoded as popcount > 8.
  function automatic logic [127:0] mb_lr_res_resp (bit success = 1);
    return mb_data_msg(MBINIT_MC_RESP, MBINIT_SC_LR_RES,
                       success ? MBINIT_LR_DATA_SUCCESS : MBINIT_LR_DATA_FAIL);
  endfunction
  function automatic logic [127:0] mb_lr_done_req (); return mb_no_data(MBINIT_MC_REQ,  MBINIT_SC_LR_DONE); endfunction
  function automatic logic [127:0] mb_lr_done_resp(); return mb_no_data(MBINIT_MC_RESP, MBINIT_SC_LR_DONE); endfunction

  function automatic logic [127:0] mb_rm_start_req (); return mb_no_data(MBINIT_MC_REQ,  MBINIT_SC_RM_START); endfunction
  function automatic logic [127:0] mb_rm_start_resp(); return mb_no_data(MBINIT_MC_RESP, MBINIT_SC_RM_START); endfunction
  function automatic logic [127:0] mb_rm_apply_req (); return mb_no_data(MBINIT_MC_REQ,  MBINIT_SC_RM_APPLY); endfunction
  function automatic logic [127:0] mb_rm_apply_resp(); return mb_no_data(MBINIT_MC_RESP, MBINIT_SC_RM_APPLY); endfunction
  function automatic logic [127:0] mb_rm_end_req   (); return mb_no_data(MBINIT_MC_REQ,  MBINIT_SC_RM_END);   endfunction
  function automatic logic [127:0] mb_rm_end_resp  (); return mb_no_data(MBINIT_MC_RESP, MBINIT_SC_RM_END);   endfunction

  // ---- Object form (parallel to sbinit_sb_msg) -----------------------------
  class mbinit_sb_msg;
    bit [4:0]  opcode;
    bit [7:0]  msg_code;
    bit [7:0]  subcode;
    bit [2:0]  msg_info;
    bit [63:0] data;

    function new();
      opcode   = 5'h0;
      msg_code = 8'h0;
      subcode  = 8'h0;
      msg_info = 3'h0;
      data     = 64'h0;
    endfunction

    function logic [127:0] pack();
      logic [127:0] r;
      r          = 128'h0;
      r[4:0]     = opcode;
      r[21:14]   = msg_code;
      r[39:32]   = subcode;
      r[42:40]   = msg_info;
      r[127:64]  = data;
      return r;
    endfunction

    static function mbinit_sb_msg unpack(logic [127:0] d);
      mbinit_sb_msg m;
      m          = new();
      m.opcode   = d[4:0];
      m.msg_code = d[21:14];
      m.subcode  = d[39:32];
      m.msg_info = d[42:40];
      m.data     = d[127:64];
      return m;
    endfunction
  endclass

endpackage

`endif
