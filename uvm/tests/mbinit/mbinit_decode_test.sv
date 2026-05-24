`ifndef MBINIT_DECODE_TEST_SV
`define MBINIT_DECODE_TEST_SV

// ---------------------------------------------------------------------------
// test_mbinit_decode  (Pass 1: focused decoder unit test)
// ---------------------------------------------------------------------------
// A self-contained unit test for mbinit_decoder. It does NOT build the MBINIT
// env or interact with the DUT - it exercises the centralized decoder over
// messages built by the production mbinit_msg_pkg helpers and checks the
// classification contract:
//
//   * each REQ/RESP message decodes to MB_EVT_SB_MSG with the right msg_kind,
//     role, and COMPARE layout
//   * decoded msgCode/subcode/msgInfo fields match what was encoded
//   * valid-but-unrecognized words are classified MB_EVT_UNKNOWN (never dropped)
//
// Run with:  make mbinit MBTEST=test_mbinit_decode
// ---------------------------------------------------------------------------
class test_mbinit_decode extends uvm_test;
  `uvm_component_utils(test_mbinit_decode)

  int unsigned checks_run;
  int unsigned checks_failed;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- kind/role/layout check -------------------------------------------
  function void check_decode(string label,
                             logic [127:0]       word,
                             mbinit_msg_kind_e   exp_msg,
                             mbinit_role_e       exp_role,
                             mbinit_evt_layout_e exp_layout);
    mbinit_event ev;
    ev = mbinit_decoder::decode_lane_word(word);
    checks_run++;
    if (ev.kind === MB_EVT_SB_MSG && ev.msg_kind === exp_msg &&
        ev.role === exp_role && ev.layout === exp_layout) begin
      `uvm_info("DECODE",
                $sformatf("  [ PASS ] %-40s -> %s / %s / %s",
                          label, ev.msg_kind.name(), ev.role.name(),
                          ev.layout.name()),
                UVM_LOW)
    end else begin
      checks_failed++;
      `uvm_error("DECODE",
                 $sformatf("FAILED %s: expected SB_MSG/%s/%s/%s, got %s/%s/%s/%s (raw=0x%032h)",
                           label, exp_msg.name(), exp_role.name(), exp_layout.name(),
                           ev.kind.name(), ev.msg_kind.name(), ev.role.name(),
                           ev.layout.name(), word))
    end
  endfunction

  // ---- UNKNOWN check -----------------------------------------------------
  function void check_unknown(string label, logic [127:0] word);
    mbinit_event ev;
    ev = mbinit_decoder::decode_lane_word(word);
    checks_run++;
    if (ev.kind === MB_EVT_UNKNOWN) begin
      `uvm_info("DECODE",
                $sformatf("  [ PASS ] %-40s -> UNKNOWN", label), UVM_LOW)
    end else begin
      checks_failed++;
      `uvm_error("DECODE",
                 $sformatf("FAILED %s: expected UNKNOWN, got %s/%s (raw=0x%032h)",
                           label, ev.kind.name(), ev.msg_kind.name(), word))
    end
  endfunction

  // ---- field-level check -------------------------------------------------
  function void check_fields(string label, logic [127:0] word,
                             bit [7:0] exp_mc, bit [7:0] exp_sc, bit [2:0] exp_info);
    mbinit_event ev;
    ev = mbinit_decoder::decode_lane_word(word);
    checks_run++;
    if (ev.msg_code === exp_mc && ev.subcode === exp_sc && ev.msg_info === exp_info) begin
      `uvm_info("DECODE",
                $sformatf("  [ PASS ] %-40s -> mc=0x%02h sc=0x%02h info=0x%01h",
                          label, ev.msg_code, ev.subcode, ev.msg_info),
                UVM_LOW)
    end else begin
      checks_failed++;
      `uvm_error("DECODE",
                 $sformatf("FAILED %s: expected mc=0x%02h sc=0x%02h info=0x%01h, got mc=0x%02h sc=0x%02h info=0x%01h",
                           label, exp_mc, exp_sc, exp_info,
                           ev.msg_code, ev.subcode, ev.msg_info))
    end
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    checks_run    = 0;
    checks_failed = 0;

    `uvm_info("DECODE",
              "=================== mbinit_decoder unit test ===================",
              UVM_LOW)

    // -- requester (REQ) messages --
    check_decode("PARAM_REQ",     mb_param_req(),      MB_MSG_PARAM,     MB_ROLE_REQ, MB_LAYOUT_COMPARE);
    check_decode("CAL_REQ",       mb_cal_req(),        MB_MSG_CAL,       MB_ROLE_REQ, MB_LAYOUT_COMPARE);
    check_decode("RCLK_INIT_REQ", mb_rclk_init_req(),  MB_MSG_RCLK_INIT, MB_ROLE_REQ, MB_LAYOUT_COMPARE);
    check_decode("RCLK_RES_REQ",  mb_rclk_res_req(),   MB_MSG_RCLK_RES,  MB_ROLE_REQ, MB_LAYOUT_COMPARE);
    check_decode("RCLK_DONE_REQ", mb_rclk_done_req(),  MB_MSG_RCLK_DONE, MB_ROLE_REQ, MB_LAYOUT_COMPARE);
    check_decode("RVAL_INIT_REQ", mb_rval_init_req(),  MB_MSG_RVAL_INIT, MB_ROLE_REQ, MB_LAYOUT_COMPARE);
    check_decode("RVAL_RES_REQ",  mb_rval_res_req(),   MB_MSG_RVAL_RES,  MB_ROLE_REQ, MB_LAYOUT_COMPARE);
    check_decode("RVAL_DONE_REQ", mb_rval_done_req(),  MB_MSG_RVAL_DONE, MB_ROLE_REQ, MB_LAYOUT_COMPARE);
    check_decode("LR_INIT_REQ",   mb_lr_init_req(),    MB_MSG_LR_INIT,   MB_ROLE_REQ, MB_LAYOUT_COMPARE);
    check_decode("LR_CLR_REQ",    mb_lr_clr_req(),     MB_MSG_LR_CLR,    MB_ROLE_REQ, MB_LAYOUT_COMPARE);
    check_decode("LR_RES_REQ",    mb_lr_res_req(),     MB_MSG_LR_RES,    MB_ROLE_REQ, MB_LAYOUT_COMPARE);
    check_decode("LR_DONE_REQ",   mb_lr_done_req(),    MB_MSG_LR_DONE,   MB_ROLE_REQ, MB_LAYOUT_COMPARE);
    check_decode("RM_START_REQ",  mb_rm_start_req(),   MB_MSG_RM_START,  MB_ROLE_REQ, MB_LAYOUT_COMPARE);
    check_decode("RM_APPLY_REQ",  mb_rm_apply_req(),   MB_MSG_RM_APPLY,  MB_ROLE_REQ, MB_LAYOUT_COMPARE);
    check_decode("RM_END_REQ",    mb_rm_end_req(),     MB_MSG_RM_END,    MB_ROLE_REQ, MB_LAYOUT_COMPARE);

    // -- responder (RESP) messages --
    check_decode("PARAM_RESP",     mb_param_resp(),         MB_MSG_PARAM,     MB_ROLE_RESP, MB_LAYOUT_COMPARE);
    check_decode("CAL_RESP",       mb_cal_resp(),           MB_MSG_CAL,       MB_ROLE_RESP, MB_LAYOUT_COMPARE);
    check_decode("RCLK_RES_RESP(ok)",   mb_rclk_res_resp(1), MB_MSG_RCLK_RES, MB_ROLE_RESP, MB_LAYOUT_COMPARE);
    check_decode("RCLK_RES_RESP(fail)", mb_rclk_res_resp(0), MB_MSG_RCLK_RES, MB_ROLE_RESP, MB_LAYOUT_COMPARE);
    check_decode("RVAL_RES_RESP(ok)",   mb_rval_res_resp(1), MB_MSG_RVAL_RES, MB_ROLE_RESP, MB_LAYOUT_COMPARE);
    check_decode("LR_RES_RESP(ok)",     mb_lr_res_resp(1),   MB_MSG_LR_RES,   MB_ROLE_RESP, MB_LAYOUT_COMPARE);
    check_decode("LR_RES_RESP(fail)",   mb_lr_res_resp(0),   MB_MSG_LR_RES,   MB_ROLE_RESP, MB_LAYOUT_COMPARE);
    check_decode("RM_END_RESP",         mb_rm_end_resp(),    MB_MSG_RM_END,   MB_ROLE_RESP, MB_LAYOUT_COMPARE);

    // -- decoded fields match what was encoded --
    check_fields("fields PARAM_REQ",        mb_param_req(),      MBINIT_MC_REQ,  MBINIT_SC_PARAM,    3'h0);
    check_fields("fields RCLK_RES_RESP(ok)",mb_rclk_res_resp(1), MBINIT_MC_RESP, MBINIT_SC_RCLK_RES, MBINIT_INFO_RCLK_SUCCESS);
    check_fields("fields RVAL_RES_RESP(ok)",mb_rval_res_resp(1), MBINIT_MC_RESP, MBINIT_SC_RVAL_RES, MBINIT_INFO_RVAL_SUCCESS);

    // -- unknown / malformed valid words --
    check_unknown("garbage word",       128'hDEAD_BEEF_0000_0000_0000_0000_1234_5678);
    check_unknown("good op/mc bad sc",   mb_no_data(MBINIT_MC_REQ, 8'hFF));
    check_unknown("good op/sc bad mc",   mb_no_data(8'h55, MBINIT_SC_PARAM));

    // -- summary --
    `uvm_info("DECODE",
              "----------------------------------------------------------------",
              UVM_LOW)
    if (checks_failed == 0)
      `uvm_info("DECODE",
                $sformatf("Overall: PASS  (%0d/%0d decode checks passed)",
                          checks_run, checks_run),
                UVM_LOW)
    else
      `uvm_info("DECODE",
                $sformatf("Overall: FAIL  (%0d/%0d decode checks failed)",
                          checks_failed, checks_run),
                UVM_LOW)
    `uvm_info("DECODE",
              "================================================================",
              UVM_LOW)

    phase.drop_objection(this);
  endtask

endclass

`endif
