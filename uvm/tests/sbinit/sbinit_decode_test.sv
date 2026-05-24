`ifndef SBINIT_DECODE_TEST_SV
`define SBINIT_DECODE_TEST_SV

// ---------------------------------------------------------------------------
// test_sbinit_decode  (Pass 1: focused decoder unit test)
// ---------------------------------------------------------------------------
// A self-contained unit test for sbinit_decoder. It does NOT build the SBINIT
// env or interact with the DUT - it exercises the centralized decoder over
// hand-built lane words and checks the classification contract:
//
//   * canonical (COMPARE) layout messages decode with layout = COMPARE
//   * alternate (CREATE)  layout messages decode with layout = CREATE
//   * the matched layout identity is reported
//   * each 64-UI clock pattern is classified CLK_PATTERN
//   * valid-but-unrecognized words are classified UNKNOWN (never dropped)
//
// Run with:  make sbinit SBTEST=test_sbinit_decode
// ---------------------------------------------------------------------------
class test_sbinit_decode extends uvm_test;
  `uvm_component_utils(test_sbinit_decode)

  int unsigned checks_run;
  int unsigned checks_failed;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- word builders ----------------------------------------------------
  // COMPARE layout: reuse the production packer so the test tracks the format.
  function logic [127:0] make_compare_msg(bit [7:0] mc, bit [7:0] sc);
    sbinit_sb_msg m;
    m          = new();
    m.opcode   = SBINIT_OP_NO_DATA;
    m.msg_code = mc;
    m.subcode  = sc;
    return m.pack();
  endfunction

  // CREATE layout: opcode widened to 8 bits, message code / subcode shifted +3.
  function logic [127:0] make_create_msg(bit [7:0] mc, bit [7:0] sc);
    logic [127:0] d;
    d        = 128'h0;
    d[7:0]   = {3'b0, SBINIT_OP_NO_DATA};
    d[24:17] = mc;
    d[42:35] = sc;
    return d;
  endfunction

  // ---- check helper -----------------------------------------------------
  function void check_decode(string label,
                             logic [127:0]       word,
                             sbinit_evt_kind_e   exp_kind,
                             sbinit_evt_layout_e exp_layout);
    sbinit_event ev;
    ev = sbinit_decoder::decode_lane_word(word);
    checks_run++;
    if (ev.kind === exp_kind && ev.layout === exp_layout) begin
      `uvm_info("DECODE",
                $sformatf("  [ PASS ] %-44s -> %s / %s",
                          label, ev.kind.name(), ev.layout.name()),
                UVM_LOW)
    end else begin
      checks_failed++;
      `uvm_error("DECODE",
                 $sformatf("FAILED %s: expected %s/%s, got %s/%s (raw=0x%032h)",
                           label, exp_kind.name(), exp_layout.name(),
                           ev.kind.name(), ev.layout.name(), word))
    end
  endfunction

  // ---- field-level check (decoded mc/sc match what was encoded) ----------
  function void check_fields(string label, logic [127:0] word,
                             bit [7:0] exp_mc, bit [7:0] exp_sc);
    sbinit_event ev;
    ev = sbinit_decoder::decode_lane_word(word);
    checks_run++;
    if (ev.msg_code === exp_mc && ev.subcode === exp_sc) begin
      `uvm_info("DECODE",
                $sformatf("  [ PASS ] %-44s -> mc=0x%02h sc=0x%02h",
                          label, ev.msg_code, ev.subcode),
                UVM_LOW)
    end else begin
      checks_failed++;
      `uvm_error("DECODE",
                 $sformatf("FAILED %s: expected mc=0x%02h sc=0x%02h, got mc=0x%02h sc=0x%02h",
                           label, exp_mc, exp_sc, ev.msg_code, ev.subcode))
    end
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    checks_run    = 0;
    checks_failed = 0;

    `uvm_info("DECODE",
              "=================== sbinit_decoder unit test ===================",
              UVM_LOW)

    // -- COMPARE (canonical) layout messages --
    check_decode("OUT_OF_RESET / compare",
                 make_compare_msg(SBINIT_MC_OUT_OF_RESET, SBINIT_SC_OOR),
                 SB_EVT_OUT_OF_RESET, SB_LAYOUT_COMPARE);
    check_decode("DONE_REQ / compare",
                 make_compare_msg(SBINIT_MC_DONE_REQ, SBINIT_SC_DONE),
                 SB_EVT_DONE_REQ, SB_LAYOUT_COMPARE);
    check_decode("DONE_RESP / compare",
                 make_compare_msg(SBINIT_MC_DONE_RESP, SBINIT_SC_DONE),
                 SB_EVT_DONE_RESP, SB_LAYOUT_COMPARE);

    // -- CREATE (alternate) layout messages --
    check_decode("OUT_OF_RESET / create",
                 make_create_msg(SBINIT_MC_OUT_OF_RESET, SBINIT_SC_OOR),
                 SB_EVT_OUT_OF_RESET, SB_LAYOUT_CREATE);
    check_decode("DONE_REQ / create",
                 make_create_msg(SBINIT_MC_DONE_REQ, SBINIT_SC_DONE),
                 SB_EVT_DONE_REQ, SB_LAYOUT_CREATE);
    check_decode("DONE_RESP / create",
                 make_create_msg(SBINIT_MC_DONE_RESP, SBINIT_SC_DONE),
                 SB_EVT_DONE_RESP, SB_LAYOUT_CREATE);

    // -- decoded fields match what was encoded, both layouts --
    check_fields("fields OUT_OF_RESET / compare",
                 make_compare_msg(SBINIT_MC_OUT_OF_RESET, SBINIT_SC_OOR),
                 SBINIT_MC_OUT_OF_RESET, SBINIT_SC_OOR);
    check_fields("fields DONE_RESP / create",
                 make_create_msg(SBINIT_MC_DONE_RESP, SBINIT_SC_DONE),
                 SBINIT_MC_DONE_RESP, SBINIT_SC_DONE);

    // -- clock-pattern classification --
    check_decode("clock pattern A",  SBINIT_CLK_PATTERN_A,  SB_EVT_CLK_PATTERN, SB_LAYOUT_NONE);
    check_decode("clock pattern 5",  SBINIT_CLK_PATTERN_5,  SB_EVT_CLK_PATTERN, SB_LAYOUT_NONE);
    check_decode("clock pattern 5A", SBINIT_CLK_PATTERN_5A, SB_EVT_CLK_PATTERN, SB_LAYOUT_NONE);
    check_decode("clock pattern A5", SBINIT_CLK_PATTERN_A5, SB_EVT_CLK_PATTERN, SB_LAYOUT_NONE);

    // -- unknown / malformed valid words --
    check_decode("garbage word",      128'hDEAD_BEEF_0000_0000_0000_0000_1234_5678,
                 SB_EVT_UNKNOWN, SB_LAYOUT_NONE);
    check_decode("right op wrong code", make_compare_msg(8'hFF, 8'hFF),
                 SB_EVT_UNKNOWN, SB_LAYOUT_NONE);

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
