// Standalone LR-02 check: generated PatternWriter PERLANEID episode (no MBInit stub).
// Ref: PatternWriter.scala — perLaneNumIter=128, perLanePatternWidth=16, mbSerializerRatio from AfeParams;
//      max cycles = (128*16)/ratio - 1 in cycleCount; data = Cat(perLaneId, perLaneId) per active lane.
`timescale 1ns/1ps

module patternwriter_tb_lr02;
  logic clock;
  logic reset;

  // DUT interface
  logic        io_interfaceIo_req_ready;
  logic        io_interfaceIo_req_valid;
  logic [1:0]  io_interfaceIo_req_bits_patternType;
  logic [2:0]  io_interfaceIo_functionalLanes;
  logic        io_interfaceIo_resp_complete;
  logic        io_mbTxLaneIo_valid;
  logic [31:0] io_mbTxLaneIo_bits_data[16];
  logic [31:0] io_mbTxLaneIo_bits_valid;
  logic [31:0] io_mbTxLaneIo_bits_clkP;
  logic [31:0] io_mbTxLaneIo_bits_clkN;
  logic [31:0] io_mbTxLaneIo_bits_trk;
  logic [31:0] io_txLfsrCtrl_pattern[16];
  logic        io_txLfsrCtrl_increment;
  logic        io_txLfsrCtrl_resetLfsr;
  logic        io_txLfsrCtrl_valid;

  // Golden per-lane 16b patterns (must match elaborated PatternWriter.sv constants)
  localparam logic [15:0] EXP_PL[16] = '{
    16'hA00A, 16'hA01A, 16'hA02A, 16'hA03A,
    16'hA04A, 16'hA05A, 16'hA06A, 16'hA07A,
    16'hA08A, 16'hA09A, 16'hA0AA, 16'hA0BA,
    16'hA0CA, 16'hA0DA, 16'hA0EA, 16'hA0FA
  };

  function automatic logic [31:0] exp_word(int unsigned lane);
    return {EXP_PL[lane], EXP_PL[lane]};
  endfunction

  PatternWriter dut (
      .clock(clock),
      .reset(reset),
      .io_interfaceIo_req_ready(io_interfaceIo_req_ready),
      .io_interfaceIo_req_valid(io_interfaceIo_req_valid),
      .io_interfaceIo_req_bits_patternType(io_interfaceIo_req_bits_patternType),
      .io_interfaceIo_functionalLanes(io_interfaceIo_functionalLanes),
      .io_interfaceIo_resp_complete(io_interfaceIo_resp_complete),
      .io_mbTxLaneIo_valid(io_mbTxLaneIo_valid),
      .io_mbTxLaneIo_bits_data_0(io_mbTxLaneIo_bits_data[0]),
      .io_mbTxLaneIo_bits_data_1(io_mbTxLaneIo_bits_data[1]),
      .io_mbTxLaneIo_bits_data_2(io_mbTxLaneIo_bits_data[2]),
      .io_mbTxLaneIo_bits_data_3(io_mbTxLaneIo_bits_data[3]),
      .io_mbTxLaneIo_bits_data_4(io_mbTxLaneIo_bits_data[4]),
      .io_mbTxLaneIo_bits_data_5(io_mbTxLaneIo_bits_data[5]),
      .io_mbTxLaneIo_bits_data_6(io_mbTxLaneIo_bits_data[6]),
      .io_mbTxLaneIo_bits_data_7(io_mbTxLaneIo_bits_data[7]),
      .io_mbTxLaneIo_bits_data_8(io_mbTxLaneIo_bits_data[8]),
      .io_mbTxLaneIo_bits_data_9(io_mbTxLaneIo_bits_data[9]),
      .io_mbTxLaneIo_bits_data_10(io_mbTxLaneIo_bits_data[10]),
      .io_mbTxLaneIo_bits_data_11(io_mbTxLaneIo_bits_data[11]),
      .io_mbTxLaneIo_bits_data_12(io_mbTxLaneIo_bits_data[12]),
      .io_mbTxLaneIo_bits_data_13(io_mbTxLaneIo_bits_data[13]),
      .io_mbTxLaneIo_bits_data_14(io_mbTxLaneIo_bits_data[14]),
      .io_mbTxLaneIo_bits_data_15(io_mbTxLaneIo_bits_data[15]),
      .io_mbTxLaneIo_bits_valid(io_mbTxLaneIo_bits_valid),
      .io_mbTxLaneIo_bits_clkP(io_mbTxLaneIo_bits_clkP),
      .io_mbTxLaneIo_bits_clkN(io_mbTxLaneIo_bits_clkN),
      .io_mbTxLaneIo_bits_trk(io_mbTxLaneIo_bits_trk),
      .io_txLfsrCtrl_pattern_0(io_txLfsrCtrl_pattern[0]),
      .io_txLfsrCtrl_pattern_1(io_txLfsrCtrl_pattern[1]),
      .io_txLfsrCtrl_pattern_2(io_txLfsrCtrl_pattern[2]),
      .io_txLfsrCtrl_pattern_3(io_txLfsrCtrl_pattern[3]),
      .io_txLfsrCtrl_pattern_4(io_txLfsrCtrl_pattern[4]),
      .io_txLfsrCtrl_pattern_5(io_txLfsrCtrl_pattern[5]),
      .io_txLfsrCtrl_pattern_6(io_txLfsrCtrl_pattern[6]),
      .io_txLfsrCtrl_pattern_7(io_txLfsrCtrl_pattern[7]),
      .io_txLfsrCtrl_pattern_8(io_txLfsrCtrl_pattern[8]),
      .io_txLfsrCtrl_pattern_9(io_txLfsrCtrl_pattern[9]),
      .io_txLfsrCtrl_pattern_10(io_txLfsrCtrl_pattern[10]),
      .io_txLfsrCtrl_pattern_11(io_txLfsrCtrl_pattern[11]),
      .io_txLfsrCtrl_pattern_12(io_txLfsrCtrl_pattern[12]),
      .io_txLfsrCtrl_pattern_13(io_txLfsrCtrl_pattern[13]),
      .io_txLfsrCtrl_pattern_14(io_txLfsrCtrl_pattern[14]),
      .io_txLfsrCtrl_pattern_15(io_txLfsrCtrl_pattern[15]),
      .io_txLfsrCtrl_increment(io_txLfsrCtrl_increment),
      .io_txLfsrCtrl_resetLfsr(io_txLfsrCtrl_resetLfsr),
      .io_txLfsrCtrl_valid(io_txLfsrCtrl_valid)
  );

  int unsigned active_cycles;
  bit        saw_complete;
  bit        saw_lfsr_increment;

  initial begin
    clock = 1'b0;
    forever #5 clock = ~clock;
  end

  always @(posedge clock) begin
    if (!reset && io_mbTxLaneIo_valid && io_txLfsrCtrl_increment)
      saw_lfsr_increment = 1'b1;
  end

  initial begin
    int unsigned lane;
    automatic int unsigned c;
    automatic bit err;

    err = 0;
    active_cycles = 0;
    saw_complete = 0;
    saw_lfsr_increment = 0;
    io_interfaceIo_req_valid = 0;
    io_interfaceIo_req_bits_patternType = 2'h0;
    io_interfaceIo_functionalLanes = 3'h3;
    foreach (io_txLfsrCtrl_pattern[i])
      io_txLfsrCtrl_pattern[i] = 32'h0;

    reset = 1'b1;
    repeat (4) @(posedge clock);
    reset = 1'b0;
    repeat (2) @(posedge clock);

    // Wait for idle (req_ready)
    c = 0;
    while (!io_interfaceIo_req_ready) begin
      @(posedge clock);
      c++;
      if (c > 1000) begin
        $fatal(1, "LR-02 TB: req_ready never 1");
      end
    end

    // Issue PERLANEID job (same code as MBInit / PatternSelect)
    io_interfaceIo_functionalLanes = 3'h3;
    io_interfaceIo_req_bits_patternType = 2'h2;
    io_interfaceIo_req_valid = 1'b1;
    @(posedge clock);
    io_interfaceIo_req_valid = 1'b0;

    // Sample while output active; count cycles and check data + no LFSR increment
    c = 0;
    while (!io_interfaceIo_resp_complete) begin
      @(posedge clock);
      c++;
      if (c > 5000) begin
        $fatal(1, "LR-02 TB: resp_complete timeout");
      end
      if (io_mbTxLaneIo_valid) begin
        active_cycles++;
        for (lane = 0; lane < 16; lane++) begin
          if (io_mbTxLaneIo_bits_data[lane] !== exp_word(lane)) begin
            $error("LR-02 TB: lane %0d data=%08h exp=%08h @cycle %0d",
                   lane, io_mbTxLaneIo_bits_data[lane], exp_word(lane), active_cycles);
            err = 1;
          end
        end
      end
    end
    saw_complete = 1;

    // Elaborated PatternWriter: PERLANEID runs (128 * 16) / 32 serializer bits = 64 cycles
    // with io_mbTxLaneIo_valid (see PatternWriter.scala perLaneNumIter / perLanePatternWidth).
    if (active_cycles !== 64) begin
      $error("LR-02 TB: expected 64 mbTx valid cycles for mbSerializerRatio=32, got %0d",
             active_cycles);
      err = 1;
    end

    if (saw_lfsr_increment) begin
      $error("LR-02 TB: txLfsrCtrl_increment asserted during PERLANEID (not unscrambled LFSR path)");
      err = 1;
    end

    if (err)
      $fatal(1, "LR-02 TB: FAILED");
    $display(
        "LR-02 TB: PASS (PERLANEID, functionalLanes=3'b011, %0d active cycles = 128*16/32, per-lane data OK)",
        active_cycles);
    $finish(0);
  end
endmodule
