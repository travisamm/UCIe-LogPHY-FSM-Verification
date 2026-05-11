`ifndef MBINIT_SEQ_SV
`define MBINIT_SEQ_SV

// ============================================================
// SB message constants
// opcode[4:0] | msgCode[21:14] | msgSubcode[39:32] | data[127:64]
// ============================================================

// PARAM (opcode=0x1B with 64b data: voltageSwing=0x1F, maxDataRate=0xF, clockMode=1)
// Byte-aligned PARAM payload: RTL decodes clockMode from resp_bits[73]
// (MBInitRequester/MBInitResponder). 0x21FF had bit73=0 → negotiated clockMode 0;
// use 0x23FF so bit73=1 while keeping bits[67:64]=maxDataRate at 4'hF.
`define MB_PARAM_REQ  128'h00000000_000023FF_00000000_0029401B
`define MB_PARAM_RESP 128'h00000000_000023FF_00000000_002A801B

// No-data messages (opcode=0x12, msgCode=0xA5 req / 0xAA resp)
`define MB_CAL_REQ       128'h00000000_00000000_00000002_00294012
`define MB_CAL_RESP      128'h00000000_00000000_00000002_002A8012

`define MB_RCLK_INIT_REQ  128'h00000000_00000000_00000003_00294012
`define MB_RCLK_INIT_RESP 128'h00000000_00000000_00000003_002A8012
`define MB_RCLK_RES_REQ        128'h00000000_00000000_00000004_00294012
// msgInfo[2:0]=0x7 → repairClkSuccess = bits(42)&(41)&(40) = 1
`define MB_RCLK_RES_RESP       128'h00000000_00000000_00000704_002A8012
// msgInfo=0 → repairClkSuccess = 0 → errorDetected (RC-03)
`define MB_RCLK_RES_RESP_FAIL  128'h00000000_00000000_00000004_002A8012
`define MB_RCLK_DONE_REQ  128'h00000000_00000000_00000008_00294012
`define MB_RCLK_DONE_RESP 128'h00000000_00000000_00000008_002A8012

`define MB_RVAL_INIT_REQ  128'h00000000_00000000_00000009_00294012
`define MB_RVAL_INIT_RESP 128'h00000000_00000000_00000009_002A8012
`define MB_RVAL_RES_REQ        128'h00000000_00000000_0000000A_00294012
// msgInfo[0]=1 → repairValSuccess = bits(40) = 1
`define MB_RVAL_RES_RESP       128'h00000000_00000000_0000010A_002A8012
// msgInfo=0 → repairValSuccess = 0 → errorDetected (RV-06)
`define MB_RVAL_RES_RESP_FAIL  128'h00000000_00000000_0000000A_002A8012
`define MB_RVAL_DONE_REQ  128'h00000000_00000000_0000000C_00294012
`define MB_RVAL_DONE_RESP 128'h00000000_00000000_0000000C_002A8012

`define MB_LR_INIT_REQ    128'h00000000_00000000_0000000D_00294012
`define MB_LR_INIT_RESP   128'h00000000_00000000_0000000D_002A8012
`define MB_LR_CLR_REQ     128'h00000000_00000000_0000000E_00294012
`define MB_LR_CLR_RESP    128'h00000000_00000000_0000000E_002A8012
`define MB_LR_RES_REQ     128'h00000000_00000000_0000000F_00294012
// opcode=0x1B (MessageWith64bData); data=0xFFFF → PopCount(bits[78:63])=15 > 8 → success
`define MB_LR_RES_RESP    128'h00000000_0000FFFF_0000000F_002A801B
// same opcode; data=0 → PopCount=0 → reversalMbSuccess=0 (LR-07)
`define MB_LR_RES_RESP_FAIL 128'h00000000_00000000_0000000F_002A801B
`define MB_LR_DONE_REQ    128'h00000000_00000000_00000010_00294012
`define MB_LR_DONE_RESP   128'h00000000_00000000_00000010_002A8012

`define MB_RM_START_REQ   128'h00000000_00000000_00000011_00294012
`define MB_RM_START_RESP  128'h00000000_00000000_00000011_002A8012
`define MB_RM_DEG_REQ     128'h00000000_00000000_00000014_00294012
`define MB_RM_DEG_RESP    128'h00000000_00000000_00000014_002A8012
`define MB_RM_END_REQ     128'h00000000_00000000_00000013_00294012
`define MB_RM_END_RESP    128'h00000000_00000000_00000013_002A8012

// ============================================================
// Base sequence for MBINIT — parameterized to mbinit transaction
// ============================================================
class mbinit_base_seq extends uvm_sequence #(mbinit_transaction);
  `uvm_object_utils(mbinit_base_seq)

  function new(string name = "mbinit_base_seq");
    super.new(name);
  endfunction

  // Helper: build and send one item
  task send_item(
    input logic        start_fsm  = 0,
    input int          delay      = 0,
    input int          hold       = 10,
    input logic        req_valid  = 0,
    input logic [127:0] req_data  = 0,
    input logic        rsp_valid  = 0,
    input logic [127:0] rsp_data  = 0,
    input int unsigned cal_done_repeat_cycles = 3
  );
    mbinit_transaction req;
    req = mbinit_transaction::type_id::create("req");
    req.start_fsm    = start_fsm;
    req.delay        = delay;
    req.hold_cycles  = hold;
    req.rx_valid     = req_valid;
    req.rx_data      = req_data;
    req.rsp_rx_valid = rsp_valid;
    req.rsp_rx_data  = rsp_data;
    req.cal_done_repeat_cycles = cal_done_repeat_cycles;
    start_item(req);
    finish_item(req);
  endtask

  virtual task body();
  endtask

endclass

// ============================================================
// seq_mbinit_full: drives the full ideal MBINIT happy path
// All 6 sub-states: PARAM → CAL → REPAIRCLK → REPAIRVAL →
//                   REVERSALMB → REPAIRMB → (MBTRAIN)
// CalDone is auto-stubbed by the driver on mbInitCalStart (rising edge).
// PatternWriter/Reader/PtTest stubs are also in the driver.
// ============================================================
class seq_mbinit_full extends mbinit_base_seq;
  `uvm_object_utils(seq_mbinit_full)

  function new(string name = "seq_mbinit_full");
    super.new(name);
  endfunction

  virtual task body();
    // 1. Start FSM
    send_item(.start_fsm(1), .delay(2), .hold(2));

    // 2. PARAM — drive PARAM_RESP to requester RX, PARAM_REQ to responder RX
    send_item(.req_valid(1), .req_data(`MB_PARAM_RESP),
              .rsp_valid(1), .rsp_data(`MB_PARAM_REQ),
              .delay(5), .hold(30));

    // 3. CAL — driver auto-pulses mbInitCalDone on mbInitCalStart
    send_item(.req_valid(1), .req_data(`MB_CAL_RESP),
              .rsp_valid(1), .rsp_data(`MB_CAL_REQ),
              .delay(5), .hold(30));

    // 4. REPAIRCLK — INIT → RESULT → DONE
    send_item(.req_valid(1), .req_data(`MB_RCLK_INIT_RESP),
              .rsp_valid(1), .rsp_data(`MB_RCLK_INIT_REQ),
              .delay(5), .hold(30));
    send_item(.req_valid(1), .req_data(`MB_RCLK_RES_RESP),
              .rsp_valid(1), .rsp_data(`MB_RCLK_RES_REQ),
              .delay(5), .hold(30));
    send_item(.req_valid(1), .req_data(`MB_RCLK_DONE_RESP),
              .rsp_valid(1), .rsp_data(`MB_RCLK_DONE_REQ),
              .delay(5), .hold(30));

    // 5. REPAIRVAL — INIT → RESULT → DONE
    send_item(.req_valid(1), .req_data(`MB_RVAL_INIT_RESP),
              .rsp_valid(1), .rsp_data(`MB_RVAL_INIT_REQ),
              .delay(5), .hold(30));
    send_item(.req_valid(1), .req_data(`MB_RVAL_RES_RESP),
              .rsp_valid(1), .rsp_data(`MB_RVAL_RES_REQ),
              .delay(5), .hold(30));
    send_item(.req_valid(1), .req_data(`MB_RVAL_DONE_RESP),
              .rsp_valid(1), .rsp_data(`MB_RVAL_DONE_REQ),
              .delay(5), .hold(30));

    // 6. REVERSALMB — INIT → CLEAR_ERROR (+ patternWriter) → RESULT → DONE
    send_item(.req_valid(1), .req_data(`MB_LR_INIT_RESP),
              .rsp_valid(1), .rsp_data(`MB_LR_INIT_REQ),
              .delay(5), .hold(30));
    send_item(.req_valid(1), .req_data(`MB_LR_CLR_RESP),
              .rsp_valid(1), .rsp_data(`MB_LR_CLR_REQ),
              .delay(5), .hold(30));
    send_item(.req_valid(1), .req_data(`MB_LR_RES_RESP),
              .rsp_valid(1), .rsp_data(`MB_LR_RES_REQ),
              .delay(5), .hold(30));
    send_item(.req_valid(1), .req_data(`MB_LR_DONE_RESP),
              .rsp_valid(1), .rsp_data(`MB_LR_DONE_REQ),
              .delay(5), .hold(30));

    // 7. REPAIRMB — START → point test → APPLY_DEGRADE (may repeat s1↔s2) → END
    send_item(.req_valid(1), .req_data(`MB_RM_START_RESP),
              .rsp_valid(1), .rsp_data(`MB_RM_START_REQ),
              .delay(2), .hold(80));
    send_item(.req_valid(1), .req_data(`MB_RM_DEG_RESP),
              .rsp_valid(1), .rsp_data(`MB_RM_DEG_REQ),
              .delay(2), .hold(120));
    send_item(.req_valid(1), .req_data(`MB_RM_DEG_RESP),
              .rsp_valid(1), .rsp_data(`MB_RM_DEG_REQ),
              .delay(2), .hold(120));
    send_item(.req_valid(1), .req_data(`MB_RM_END_RESP),
              .rsp_valid(1), .rsp_data(`MB_RM_END_REQ),
              .delay(2), .hold(200));
  endtask
endclass

// ============================================================
// seq_mbinit_param_only: drives just the PARAM phase (MP tests)
// ============================================================
class seq_mbinit_param_only extends mbinit_base_seq;
  `uvm_object_utils(seq_mbinit_param_only)

  function new(string name = "seq_mbinit_param_only");
    super.new(name);
  endfunction

  virtual task body();
    send_item(.start_fsm(1), .delay(2), .hold(2));
    send_item(.req_valid(1), .req_data(`MB_PARAM_RESP),
              .rsp_valid(1), .rsp_data(`MB_PARAM_REQ),
              .delay(5), .hold(50));
  endtask
endclass

// ============================================================
// seq_mbinit_cal_only: PARAM → CAL (MC-01/02, MP-06) then stop.
// Uses a long mbInitCalDone delay on the CAL beat so the DUT stays in sCAL
// until calibration completes (REQ.valid gated on mbInitCalDone in RTL).
// ============================================================
class seq_mbinit_cal_only extends mbinit_base_seq;
  `uvm_object_utils(seq_mbinit_cal_only)

  function new(string name = "seq_mbinit_cal_only");
    super.new(name);
  endfunction

  virtual task body();
    send_item(.start_fsm(1), .delay(2), .hold(2));
    send_item(.req_valid(1), .req_data(`MB_PARAM_RESP),
              .rsp_valid(1), .rsp_data(`MB_PARAM_REQ),
              .delay(5), .hold(30));
    send_item(.req_valid(1), .req_data(`MB_CAL_RESP),
              .rsp_valid(1), .rsp_data(`MB_CAL_REQ),
              .delay(5), .hold(40), .cal_done_repeat_cycles(64));
  endtask
endclass

// ============================================================
// seq_mbinit_repairclk_only: PARAM → CAL → full REPAIRCLK (RC-01/02/05)
// Stops after REPAIRCLK DONE exchange; DUT should enter REPAIRVAL (RC-05).
// ============================================================
class seq_mbinit_repairclk_only extends mbinit_base_seq;
  `uvm_object_utils(seq_mbinit_repairclk_only)

  function new(string name = "seq_mbinit_repairclk_only");
    super.new(name);
  endfunction

  virtual task body();
    send_item(.start_fsm(1), .delay(2), .hold(2));
    send_item(.req_valid(1), .req_data(`MB_PARAM_RESP),
              .rsp_valid(1), .rsp_data(`MB_PARAM_REQ),
              .delay(5), .hold(30));
    send_item(.req_valid(1), .req_data(`MB_CAL_RESP),
              .rsp_valid(1), .rsp_data(`MB_CAL_REQ),
              .delay(5), .hold(30), .cal_done_repeat_cycles(3));
    send_item(.req_valid(1), .req_data(`MB_RCLK_INIT_RESP),
              .rsp_valid(1), .rsp_data(`MB_RCLK_INIT_REQ),
              .delay(5), .hold(30));
    send_item(.req_valid(1), .req_data(`MB_RCLK_RES_RESP),
              .rsp_valid(1), .rsp_data(`MB_RCLK_RES_REQ),
              .delay(5), .hold(30));
    send_item(.req_valid(1), .req_data(`MB_RCLK_DONE_RESP),
              .rsp_valid(1), .rsp_data(`MB_RCLK_DONE_REQ),
              .delay(5), .hold(80));
  endtask
endclass

// ============================================================
// seq_mbinit_repairclk_fail: RC-03 — unrepairable clock repair
// PARAM → CAL → REPAIRCLK INIT → REPAIRCLK RESULT (failure)
// msgInfo=0 → repairClkSuccess=0 → errorDetected (RC-03)
// ============================================================
class seq_mbinit_repairclk_fail extends mbinit_base_seq;
  `uvm_object_utils(seq_mbinit_repairclk_fail)

  function new(string name = "seq_mbinit_repairclk_fail");
    super.new(name);
  endfunction

  virtual task body();
    send_item(.start_fsm(1), .delay(2), .hold(2));

    send_item(.req_valid(1), .req_data(`MB_PARAM_RESP),
              .rsp_valid(1), .rsp_data(`MB_PARAM_REQ),
              .delay(5), .hold(30));

    send_item(.req_valid(1), .req_data(`MB_CAL_RESP),
              .rsp_valid(1), .rsp_data(`MB_CAL_REQ),
              .delay(5), .hold(30));

    send_item(.req_valid(1), .req_data(`MB_RCLK_INIT_RESP),
              .rsp_valid(1), .rsp_data(`MB_RCLK_INIT_REQ),
              .delay(5), .hold(30));

    // Drive failure result: requester gets msgInfo=0 → errorDetected
    send_item(.req_valid(1), .req_data(`MB_RCLK_RES_RESP_FAIL),
              .rsp_valid(1), .rsp_data(`MB_RCLK_RES_REQ),
              .delay(5), .hold(30));
  endtask
endclass

// ============================================================
// seq_mbinit_repairval_fail: RV-06 — unrepairable valid repair
// Full REPAIRCLK success → REPAIRVAL INIT → REPAIRVAL RESULT (failure)
// msgInfo=0 → repairValSuccess=0 → fsmCtrl_error asserted
// ============================================================
class seq_mbinit_repairval_fail extends mbinit_base_seq;
  `uvm_object_utils(seq_mbinit_repairval_fail)

  function new(string name = "seq_mbinit_repairval_fail");
    super.new(name);
  endfunction

  virtual task body();
    send_item(.start_fsm(1), .delay(2), .hold(2));

    send_item(.req_valid(1), .req_data(`MB_PARAM_RESP),
              .rsp_valid(1), .rsp_data(`MB_PARAM_REQ),
              .delay(5), .hold(30));

    send_item(.req_valid(1), .req_data(`MB_CAL_RESP),
              .rsp_valid(1), .rsp_data(`MB_CAL_REQ),
              .delay(5), .hold(30));

    // Full REPAIRCLK with success (required before REPAIRVAL)
    send_item(.req_valid(1), .req_data(`MB_RCLK_INIT_RESP),
              .rsp_valid(1), .rsp_data(`MB_RCLK_INIT_REQ),
              .delay(5), .hold(30));
    send_item(.req_valid(1), .req_data(`MB_RCLK_RES_RESP),
              .rsp_valid(1), .rsp_data(`MB_RCLK_RES_REQ),
              .delay(5), .hold(30));
    send_item(.req_valid(1), .req_data(`MB_RCLK_DONE_RESP),
              .rsp_valid(1), .rsp_data(`MB_RCLK_DONE_REQ),
              .delay(5), .hold(30));

    send_item(.req_valid(1), .req_data(`MB_RVAL_INIT_RESP),
              .rsp_valid(1), .rsp_data(`MB_RVAL_INIT_REQ),
              .delay(5), .hold(30));

    // Drive failure result: requester gets msgInfo=0 → errorDetected
    send_item(.req_valid(1), .req_data(`MB_RVAL_RES_RESP_FAIL),
              .rsp_valid(1), .rsp_data(`MB_RVAL_RES_REQ),
              .delay(5), .hold(30));
  endtask
endclass

// ============================================================
// seq_mbinit_param_mismatch: incompatible params → expect error
// Drives zero data in PARAM_REQ to responder (clockMode=0, maxDataRate=0)
// which mismatches local settings (clockMode=1, maxDataRate=0xF)
// ============================================================
class seq_mbinit_param_mismatch extends mbinit_base_seq;
  `uvm_object_utils(seq_mbinit_param_mismatch)

  // PARAM_REQ with zeroed data field (all params = 0)
  localparam logic [127:0] MISMATCH_REQ =
    128'h00000000_00000000_00000000_0029401B;

  function new(string name = "seq_mbinit_param_mismatch");
    super.new(name);
  endfunction

  virtual task body();
    send_item(.start_fsm(1), .delay(2), .hold(2));
    send_item(.req_valid(1), .req_data(`MB_PARAM_RESP),
              .rsp_valid(1), .rsp_data(MISMATCH_REQ),
              .delay(5), .hold(50));
  endtask
endclass

`endif
