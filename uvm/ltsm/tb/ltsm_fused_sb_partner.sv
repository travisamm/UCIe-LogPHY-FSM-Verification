// Reactive fused sideband partner for LinkTrainingSM TB: SBINIT + MBINIT (incl. RV-06
// REPAIRVAL fail) + TRAINERROR_ENTRY RESP when DUT sends REQ (TE-02/TE-03 style).
`ifndef LTSM_FUSED_SB_PARTNER_SV
`define LTSM_FUSED_SB_PARTNER_SV

`define LTSM_OP(d) d[4:0]
`define LTSM_MC(d) d[21:14]
`define LTSM_SC(d) d[39:32]

module ltsm_fused_sb_partner (
    input  logic        clk,
    input  logic        rst,
    input  logic [3:0]  lt_state,
    input  logic        dut_tx_valid,
    input  logic [127:0] dut_tx_data,
    input  logic        dut_tx_ready,
    output logic        dut_rx_valid,
    output logic [127:0] dut_rx_data
);

  // --- SBINIT (logphy_sbinit_seq.sv) ---
  localparam logic [127:0] SB_PAT = 128'h00000000_00000000_55555555_55555555;
  localparam logic [127:0] SB_OOR = 128'h00000000_00000000_00000000_00244012;
  localparam logic [127:0] SB_DONE_RESP = 128'h00000000_00000000_00000001_00268012;

  // --- MBINIT (mbinit_seq.sv) ---
  localparam logic [127:0] MB_PARAM_REQ = 128'h00000000_000023FF_00000000_0029401B;
  localparam logic [127:0] MB_PARAM_RESP = 128'h00000000_000023FF_00000000_002A801B;
  localparam logic [127:0] MB_CAL_REQ = 128'h00000000_00000000_00000002_00294012;
  localparam logic [127:0] MB_CAL_RESP = 128'h00000000_00000000_00000002_002A8012;
  localparam logic [127:0] MB_RCLK_INIT_REQ = 128'h00000000_00000000_00000003_00294012;
  localparam logic [127:0] MB_RCLK_INIT_RESP = 128'h00000000_00000000_00000003_002A8012;
  localparam logic [127:0] MB_RCLK_RES_REQ = 128'h00000000_00000000_00000004_00294012;
  localparam logic [127:0] MB_RCLK_RES_RESP = 128'h00000000_00000000_00000704_002A8012;
  localparam logic [127:0] MB_RCLK_DONE_REQ = 128'h00000000_00000000_00000008_00294012;
  localparam logic [127:0] MB_RCLK_DONE_RESP = 128'h00000000_00000000_00000008_002A8012;
  localparam logic [127:0] MB_RVAL_INIT_REQ = 128'h00000000_00000000_00000009_00294012;
  localparam logic [127:0] MB_RVAL_INIT_RESP = 128'h00000000_00000000_00000009_002A8012;
  localparam logic [127:0] MB_RVAL_RES_REQ = 128'h00000000_00000000_0000000A_00294012;
  localparam logic [127:0] MB_RVAL_RES_RESP_FAIL = 128'h00000000_00000000_0000000A_002A8012;

  // TRAINERROR_ENTRY (SidebandMessageEncodings.scala): opcode 0x12, msg E5/EA, sub 0x00
  localparam logic [127:0] TRAINERROR_ENTRY_RESP = 128'h00000000_00000000_00000000_003A8012;

  logic [15:0] sbinit_phase;

  wire sbinit_tx_is_pat = dut_tx_valid && dut_tx_ready && (dut_tx_data[63:0] == 64'h5555555555555555);
  wire sbinit_tx_done_req = dut_tx_valid && dut_tx_ready &&
         (`LTSM_OP(dut_tx_data) == 5'h12) && (`LTSM_MC(dut_tx_data) == 8'h95);
  wire trainerror_tx_req = dut_tx_valid && dut_tx_ready &&
         (`LTSM_OP(dut_tx_data) == 5'h12) && (`LTSM_MC(dut_tx_data) == 8'hE5);

  function automatic logic [127:0] mb_reply(input logic [127:0] d);
    if (`LTSM_OP(d) == 5'h1B && `LTSM_MC(d) == 8'hA5 && `LTSM_SC(d) == 8'h00) return MB_PARAM_RESP;
    if (`LTSM_OP(d) == 5'h12 && `LTSM_MC(d) == 8'hA5 && `LTSM_SC(d) == 8'h02) return MB_CAL_RESP;
    if (`LTSM_OP(d) == 5'h12 && `LTSM_MC(d) == 8'hA5 && `LTSM_SC(d) == 8'h03) return MB_RCLK_INIT_RESP;
    if (`LTSM_OP(d) == 5'h12 && `LTSM_MC(d) == 8'hA5 && `LTSM_SC(d) == 8'h04) return MB_RCLK_RES_RESP;
    if (`LTSM_OP(d) == 5'h12 && `LTSM_MC(d) == 8'hA5 && `LTSM_SC(d) == 8'h08) return MB_RCLK_DONE_RESP;
    if (`LTSM_OP(d) == 5'h12 && `LTSM_MC(d) == 8'hA5 && `LTSM_SC(d) == 8'h09) return MB_RVAL_INIT_RESP;
    if (`LTSM_OP(d) == 5'h12 && `LTSM_MC(d) == 8'hA5 && `LTSM_SC(d) == 8'h0A) return MB_RVAL_RES_RESP_FAIL;
    return 128'd0;
  endfunction

  wire [127:0] mb_rsp = mb_reply(dut_tx_data);
  wire mb_hit = dut_tx_valid && dut_tx_ready && (lt_state == 4'd2) && (mb_rsp != 128'd0);

  always_ff @(posedge clk) begin
    if (rst) begin
      sbinit_phase <= 0;
    end else begin
      if (lt_state != 4'd1) sbinit_phase <= 0;
      else if (sbinit_tx_is_pat || sbinit_phase != 0) sbinit_phase <= sbinit_phase + 1'b1;
    end
  end

  always_comb begin
    dut_rx_valid = 1'b0;
    dut_rx_data  = 128'd0;
    // TrainError: same physical SB as MBINIT — respond to DUT-originated TE REQ
    if (trainerror_tx_req) begin
      dut_rx_valid = 1'b1;
      dut_rx_data  = TRAINERROR_ENTRY_RESP;
    end else if (lt_state == 4'd1) begin
      // SBINIT: pattern + OOR window, then hold DONE RESP while DUT sends DONE REQ
      if (sbinit_phase < 16'd80) begin
        dut_rx_valid = 1'b1;
        dut_rx_data  = SB_PAT;
      end else if (sbinit_phase < 16'd120) begin
        dut_rx_valid = 1'b1;
        dut_rx_data  = SB_OOR;
      end else if (sbinit_tx_done_req) begin
        dut_rx_valid = 1'b1;
        dut_rx_data  = SB_DONE_RESP;
      end
    end else if (mb_hit) begin
      dut_rx_valid = 1'b1;
      dut_rx_data  = mb_rsp;
    end
  end

endmodule
`endif
