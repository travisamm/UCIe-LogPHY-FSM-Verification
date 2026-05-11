`ifndef MBTRAIN_SEQ_SV
`define MBTRAIN_SEQ_SV

// ============================================================
// SB message constants
// opcode[4:0]=0x12 | msgCode[21:14]=0xB5(REQ)/0xBA(RESP) | msgSubcode[39:32]=SC | data=0
// Lower 32-bit word: REQ=0x002D4012  RESP=0x002E8012
// ============================================================

// VALVREF
`define MT_VV_START_REQ  128'h00000000_00000000_00000000_002D4012
`define MT_VV_START_RESP 128'h00000000_00000000_00000000_002E8012
`define MT_VV_END_REQ    128'h00000000_00000000_00000001_002D4012
`define MT_VV_END_RESP   128'h00000000_00000000_00000001_002E8012

// DATAVREF
`define MT_DV_START_REQ  128'h00000000_00000000_00000002_002D4012
`define MT_DV_START_RESP 128'h00000000_00000000_00000002_002E8012
`define MT_DV_END_REQ    128'h00000000_00000000_00000003_002D4012
`define MT_DV_END_RESP   128'h00000000_00000000_00000003_002E8012

// SPEEDIDLE
`define MT_SI_DONE_REQ   128'h00000000_00000000_00000004_002D4012
`define MT_SI_DONE_RESP  128'h00000000_00000000_00000004_002E8012

// TXSELFCAL (driver auto-stubs trainingCtrl_txSelfCalDone on txSelfCalStart)
`define MT_TC_DONE_REQ   128'h00000000_00000000_00000005_002D4012
`define MT_TC_DONE_RESP  128'h00000000_00000000_00000005_002E8012

// RXCLKCAL (driver auto-stubs trainingCtrl_rxClkCalDone on rxClkCalStart)
`define MT_RCC_START_REQ  128'h00000000_00000000_00000006_002D4012
`define MT_RCC_START_RESP 128'h00000000_00000000_00000006_002E8012
`define MT_RCC_DONE_REQ   128'h00000000_00000000_00000007_002D4012
`define MT_RCC_DONE_RESP  128'h00000000_00000000_00000007_002E8012

// VALTRAINCENTER
`define MT_VTC_START_REQ  128'h00000000_00000000_00000008_002D4012
`define MT_VTC_START_RESP 128'h00000000_00000000_00000008_002E8012
`define MT_VTC_DONE_REQ   128'h00000000_00000000_00000009_002D4012
`define MT_VTC_DONE_RESP  128'h00000000_00000000_00000009_002E8012

// VALTRAINVREF
`define MT_VTV_START_REQ  128'h00000000_00000000_0000000A_002D4012
`define MT_VTV_START_RESP 128'h00000000_00000000_0000000A_002E8012
`define MT_VTV_DONE_REQ   128'h00000000_00000000_0000000B_002D4012
`define MT_VTV_DONE_RESP  128'h00000000_00000000_0000000B_002E8012

// DATATRAINCENTER1
`define MT_DC1_START_REQ  128'h00000000_00000000_0000000C_002D4012
`define MT_DC1_START_RESP 128'h00000000_00000000_0000000C_002E8012
`define MT_DC1_END_REQ    128'h00000000_00000000_0000000D_002D4012
`define MT_DC1_END_RESP   128'h00000000_00000000_0000000D_002E8012

// DATATRAINVREF
`define MT_DTV_START_REQ  128'h00000000_00000000_0000000E_002D4012
`define MT_DTV_START_RESP 128'h00000000_00000000_0000000E_002E8012
`define MT_DTV_END_REQ    128'h00000000_00000000_00000010_002D4012
`define MT_DTV_END_RESP   128'h00000000_00000000_00000010_002E8012

// RXDESKEW
`define MT_RDS_START_REQ  128'h00000000_00000000_00000011_002D4012
`define MT_RDS_START_RESP 128'h00000000_00000000_00000011_002E8012
`define MT_RDS_END_REQ    128'h00000000_00000000_00000012_002D4012
`define MT_RDS_END_RESP   128'h00000000_00000000_00000012_002E8012

// DATATRAINCENTER2
`define MT_DC2_START_REQ  128'h00000000_00000000_00000013_002D4012
`define MT_DC2_START_RESP 128'h00000000_00000000_00000013_002E8012
`define MT_DC2_END_REQ    128'h00000000_00000000_00000014_002D4012
`define MT_DC2_END_RESP   128'h00000000_00000000_00000014_002E8012

// LINKSPEED
`define MT_LS_START_REQ  128'h00000000_00000000_00000015_002D4012
`define MT_LS_START_RESP 128'h00000000_00000000_00000015_002E8012
`define MT_LS_DONE_REQ   128'h00000000_00000000_00000019_002D4012
`define MT_LS_DONE_RESP  128'h00000000_00000000_00000019_002E8012

// ============================================================
// Base sequence for MBTrain
// ============================================================
class mbtrain_base_seq extends uvm_sequence #(mbtrain_transaction);
  `uvm_object_utils(mbtrain_base_seq)

  function new(string name = "mbtrain_base_seq");
    super.new(name);
  endfunction

  task send_item(
    input logic        start_fsm  = 0,
    input int          delay      = 0,
    input int          hold       = 10,
    input logic        req_valid  = 0,
    input logic [127:0] req_data  = 0,
    input logic        rsp_valid  = 0,
    input logic [127:0] rsp_data  = 0,
    input logic        training_req_start = 0,
    input logic [1:0]  training_req_kind  = 2'h0,
    input logic        training_req_complete = 0,
    input logic [15:0] max_error_threshold = 16'hFFFF,
    input logic [3:0]  negotiated_rate = 4'h3
  );
    mbtrain_transaction req;
    req = mbtrain_transaction::type_id::create("req");
    req.start_fsm                = start_fsm;
    req.delay                    = delay;
    req.hold_cycles              = hold;
    req.rx_valid                 = req_valid;
    req.rx_data                  = req_data;
    req.rsp_rx_valid             = rsp_valid;
    req.rsp_rx_data              = rsp_data;
    req.trainingReqStart         = training_req_start;
    req.trainingReqTestKind      = training_req_kind;
    req.trainingReqComplete      = training_req_complete;
    req.maxErrorThresholdPerLane = max_error_threshold;
    req.negotiatedMaxDataRate    = negotiated_rate;
    start_item(req);
    finish_item(req);
  endtask

  task run_training_point_op(input logic [15:0] max_error_threshold = 16'hFFFF);
    send_item(.training_req_start(1), .training_req_kind(2'h0),
              .delay(5), .hold(2), .max_error_threshold(max_error_threshold));
    send_item(.delay(10), .hold(1), .max_error_threshold(max_error_threshold));
    send_item(.training_req_complete(1), .delay(2), .hold(2),
              .max_error_threshold(max_error_threshold));
  endtask

  virtual task body();
  endtask

endclass

// ============================================================
// seq_mbtrain_valvref: focused VV-01/02/03/04/06 sequence
// VALVREF START -> one point-test link op -> VALVREF END -> DATAVREF
// ============================================================
class seq_mbtrain_valvref extends mbtrain_base_seq;
  `uvm_object_utils(seq_mbtrain_valvref)

  function new(string name = "seq_mbtrain_valvref");
    super.new(name);
  endfunction

  virtual task body();
    send_item(.start_fsm(1),
              .req_valid(1), .req_data(`MT_VV_START_RESP),
              .rsp_valid(1), .rsp_data(`MT_VV_START_REQ),
              .delay(2), .hold(30), .max_error_threshold(16'h0007));

    run_training_point_op(16'h0007);

    send_item(.req_valid(1), .req_data(`MT_VV_END_RESP),
              .rsp_valid(1), .rsp_data(`MT_VV_END_REQ),
              .delay(5), .hold(30), .max_error_threshold(16'h0007));
  endtask
endclass

// ============================================================
// seq_mbtrain_datavref: focused DV-01/02/03 sequence
// Drives through VALVREF, then checks DATAVREF link-op behavior and exit.
// ============================================================
class seq_mbtrain_datavref extends mbtrain_base_seq;
  `uvm_object_utils(seq_mbtrain_datavref)

  function new(string name = "seq_mbtrain_datavref");
    super.new(name);
  endfunction

  virtual task body();
    send_item(.start_fsm(1),
              .req_valid(1), .req_data(`MT_VV_START_RESP),
              .rsp_valid(1), .rsp_data(`MT_VV_START_REQ),
              .delay(2), .hold(30), .max_error_threshold(16'h0009));
    send_item(.training_req_complete(1), .delay(5), .hold(2),
              .max_error_threshold(16'h0009));
    send_item(.req_valid(1), .req_data(`MT_VV_END_RESP),
              .rsp_valid(1), .rsp_data(`MT_VV_END_REQ),
              .delay(5), .hold(30), .max_error_threshold(16'h0009));

    send_item(.req_valid(1), .req_data(`MT_DV_START_RESP),
              .rsp_valid(1), .rsp_data(`MT_DV_START_REQ),
              .delay(5), .hold(30), .max_error_threshold(16'h0009));

    run_training_point_op(16'h0009);

    send_item(.req_valid(1), .req_data(`MT_DV_END_RESP),
              .rsp_valid(1), .rsp_data(`MT_DV_END_REQ),
              .delay(5), .hold(30), .max_error_threshold(16'h0009));
  endtask
endclass

// ============================================================
// seq_mbtrain_full: full happy-path through all 12 sub-states
//
// VALVREF → DATAVREF → SPEEDIDLE → TXSELFCAL → RXCLKCAL →
// VALTRAINCENTER → VALTRAINVREF → DATATRAINCENTER1 →
// DATATRAINVREF → RXDESKEW → DATATRAINCENTER2 → LINKSPEED
//
// TxSelfCal and RxClkCal are auto-stubbed by the driver.
// All 4 test interface stubs (ptTest/eyeSweep req+resp) are also driver-handled.
// pllLock defaults to 1 in the driver for SPEEDIDLE to proceed.
// ============================================================
class seq_mbtrain_full extends mbtrain_base_seq;
  `uvm_object_utils(seq_mbtrain_full)

  function new(string name = "seq_mbtrain_full");
    super.new(name);
  endfunction

  virtual task body();
    // 1. Start FSM and complete VALVREF START while fsmCtrl_start is high.
    send_item(.start_fsm(1),
              .req_valid(1), .req_data(`MT_VV_START_RESP),
              .rsp_valid(1), .rsp_data(`MT_VV_START_REQ),
              .delay(2), .hold(30));
    run_training_point_op();
    send_item(.req_valid(1), .req_data(`MT_VV_END_RESP),
              .rsp_valid(1), .rsp_data(`MT_VV_END_REQ),
              .delay(5), .hold(30));

    // 3. DATAVREF
    send_item(.req_valid(1), .req_data(`MT_DV_START_RESP),
              .rsp_valid(1), .rsp_data(`MT_DV_START_REQ),
              .delay(5), .hold(30));
    run_training_point_op();
    send_item(.req_valid(1), .req_data(`MT_DV_END_RESP),
              .rsp_valid(1), .rsp_data(`MT_DV_END_REQ),
              .delay(5), .hold(30));

    // 4. SPEEDIDLE (pllLock=1 is driver default; goToState routes to TXSELFCAL)
    send_item(.req_valid(1), .req_data(`MT_SI_DONE_RESP),
              .rsp_valid(1), .rsp_data(`MT_SI_DONE_REQ),
              .delay(5), .hold(30));

    // 5. TXSELFCAL (driver auto-stubs trainingCtrl_txSelfCalDone).
    // Drive the requester response first so a stale requesterRdy cannot let
    // the responder half advance the state before TXSELFCAL_DONE_REQ is sent.
    send_item(.req_valid(1), .req_data(`MT_TC_DONE_RESP),
              .delay(5), .hold(80));
    send_item(.rsp_valid(1), .rsp_data(`MT_TC_DONE_REQ),
              .delay(5), .hold(30));

    // 6. RXCLKCAL (driver auto-stubs trainingCtrl_rxClkCalDone)
    send_item(.req_valid(1), .req_data(`MT_RCC_START_RESP),
              .rsp_valid(1), .rsp_data(`MT_RCC_START_REQ),
              .delay(5), .hold(30));
    send_item(.req_valid(1), .req_data(`MT_RCC_DONE_RESP),
              .rsp_valid(1), .rsp_data(`MT_RCC_DONE_REQ),
              .delay(5), .hold(30));

    // 7. VALTRAINCENTER
    send_item(.req_valid(1), .req_data(`MT_VTC_START_RESP),
              .rsp_valid(1), .rsp_data(`MT_VTC_START_REQ),
              .delay(5), .hold(30));
    run_training_point_op();
    send_item(.req_valid(1), .req_data(`MT_VTC_DONE_RESP),
              .rsp_valid(1), .rsp_data(`MT_VTC_DONE_REQ),
              .delay(5), .hold(30));

    // 8. VALTRAINVREF
    send_item(.req_valid(1), .req_data(`MT_VTV_START_RESP),
              .rsp_valid(1), .rsp_data(`MT_VTV_START_REQ),
              .delay(5), .hold(30));
    run_training_point_op();
    send_item(.req_valid(1), .req_data(`MT_VTV_DONE_RESP),
              .rsp_valid(1), .rsp_data(`MT_VTV_DONE_REQ),
              .delay(5), .hold(30));

    // 9. DATATRAINCENTER1
    send_item(.req_valid(1), .req_data(`MT_DC1_START_RESP),
              .rsp_valid(1), .rsp_data(`MT_DC1_START_REQ),
              .delay(5), .hold(30));
    run_training_point_op();
    send_item(.req_valid(1), .req_data(`MT_DC1_END_RESP),
              .rsp_valid(1), .rsp_data(`MT_DC1_END_REQ),
              .delay(5), .hold(30));

    // 10. DATATRAINVREF
    send_item(.req_valid(1), .req_data(`MT_DTV_START_RESP),
              .rsp_valid(1), .rsp_data(`MT_DTV_START_REQ),
              .delay(5), .hold(30));
    run_training_point_op();
    send_item(.req_valid(1), .req_data(`MT_DTV_END_RESP),
              .rsp_valid(1), .rsp_data(`MT_DTV_END_REQ),
              .delay(5), .hold(30));

    // 11. RXDESKEW
    send_item(.req_valid(1), .req_data(`MT_RDS_START_RESP),
              .rsp_valid(1), .rsp_data(`MT_RDS_START_REQ),
              .delay(5), .hold(30));
    run_training_point_op();
    send_item(.req_valid(1), .req_data(`MT_RDS_END_RESP),
              .rsp_valid(1), .rsp_data(`MT_RDS_END_REQ),
              .delay(5), .hold(30));

    // 12. DATATRAINCENTER2
    send_item(.req_valid(1), .req_data(`MT_DC2_START_RESP),
              .rsp_valid(1), .rsp_data(`MT_DC2_START_REQ),
              .delay(5), .hold(30));
    run_training_point_op();
    send_item(.req_valid(1), .req_data(`MT_DC2_END_RESP),
              .rsp_valid(1), .rsp_data(`MT_DC2_END_REQ),
              .delay(5), .hold(30));

    // 13. LINKSPEED
    send_item(.req_valid(1), .req_data(`MT_LS_START_RESP),
              .rsp_valid(1), .rsp_data(`MT_LS_START_REQ),
              .delay(5), .hold(30));
    send_item(.req_valid(1), .req_data(`MT_LS_DONE_RESP),
              .rsp_valid(1), .rsp_data(`MT_LS_DONE_REQ),
              .delay(5), .hold(30));
  endtask
endclass

`endif
