`ifndef LOGPHY_SVA_SV
`define LOGPHY_SVA_SV

// ============================================================
// SVA 1: SB mode must transition RAW->PACKET after pattern detection
// Once currentState reaches FUNCTIONAL (2'h2), rxTxMode must be 1
// Spec: SB-05 — After detection, SB Tx/Rx must be enabled for
//               functional sideband messages
// ============================================================
module sbinit_sva (
  input wire clock,
  input wire reset,
  input wire [1:0] currentState,
  input wire       rxTxMode
);

  // rxTxMode must be 1 when in FUNCTIONAL state
  property p_sb_mode_functional;
    @(posedge clock) disable iff (reset)
    (currentState == 2'h2) |-> rxTxMode;
  endproperty


  // Once rxTxMode goes high it must not go low (sticky)
  property p_sb_mode_sticky;
    @(posedge clock) disable iff (reset)
    rxTxMode |=> rxTxMode;
  endproperty

  a_sb_mode_functional: assert property (p_sb_mode_functional)
    else $error("SVA FAIL: SB-05 rxTxMode not set in FUNCTIONAL state");

  a_sb_mode_sticky: assert property (p_sb_mode_sticky)
    else $error("SVA FAIL: SB-05 rxTxMode deasserted after going high");

endmodule

// ============================================================
// SVA 2: VALTRAIN pattern must NOT be scrambled
// patternType=1 (VALTRAIN) -> LFSR pattern input should be all zeros
// Spec: XC-09
// ============================================================
module patternwriter_sva (
  input wire        clock,
  input wire        reset,
  input wire        req_valid,
  input wire [1:0]  patternType,
  input wire [31:0] lfsr_pattern_0,
  input wire [31:0] lfsr_pattern_1
);

  // When VALTRAIN (type=1) is requested, LFSR patterns should be 0 (unscrambled)
  property p_valtrain_unscrambled;
    @(posedge clock) disable iff (reset)
    (req_valid && patternType == 2'h1) |->
      (lfsr_pattern_0 == 32'h0 && lfsr_pattern_1 == 32'h0);
  endproperty

  // When Per Lane ID (type=2) is requested, LFSR patterns should be 0 (unscrambled)
  property p_perlane_unscrambled;
    @(posedge clock) disable iff (reset)
    (req_valid && patternType == 2'h2) |->
      (lfsr_pattern_0 == 32'h0 && lfsr_pattern_1 == 32'h0);
  endproperty

  a_valtrain_unscrambled: assert property (p_valtrain_unscrambled)
    else $error("SVA FAIL: XC-09 VALTRAIN pattern appears scrambled");

  a_perlane_unscrambled: assert property (p_perlane_unscrambled)
    else $error("SVA FAIL: XC-10 Per Lane ID pattern appears scrambled");

endmodule

// ============================================================
// SVA 3: MBInit requester and responder state must be synchronized
// Both must be in the same state at every transition
// Spec: XC-03
// ============================================================
module mbinit_state_sync_sva (
  input wire        clock,
  input wire        reset,
  input wire [2:0]  requester_state,
  input wire [2:0]  responder_state
);

  // States must match within one cycle of each other
  property p_state_sync;
    @(posedge clock) disable iff (reset)
    ##1 (requester_state != responder_state) |->
        ##1 (requester_state == responder_state);
  endproperty

  a_state_sync: assert property (p_state_sync)
    else $error("SVA FAIL: XC-03 requester/responder states out of sync");

endmodule
// ============================================================
// SVA: XC-07 — Valid framing must be correct when LFSR pattern transmitted
// When patternType=0 (LFSR), mbTxLaneIo_bits_valid must be asserted
// Spec: XC-07
// ============================================================
module patternwriter_valid_framing_sva (
  input wire        clock,
  input wire        reset,
  input wire        inProgress,
  input wire [1:0]  patternTypeReg,
  input wire [31:0] bits_valid
);

  // When LFSR pattern (type=0) is active, valid framing must be non-zero
  property p_lfsr_valid_framing;
    @(posedge clock) disable iff (reset)
    (inProgress && patternTypeReg == 2'h0) |->
      (bits_valid != 32'h0);
  endproperty

  a_lfsr_valid_framing: assert property (p_lfsr_valid_framing)
    else $error("SVA FAIL: XC-07 LFSR pattern transmitted without valid framing");

endmodule

// ============================================================
// SVA: XC-08 — LFSR must follow polynomial per UCIe spec 4.4.1
// Checks: correct reset seed, never all-zero degenerate state
// Spec: XC-08
// ============================================================
module lfsr_sva (
  input wire        clock,
  input wire        reset,
  input wire        io_resetLfsr,
  input wire        io_increment,
  input wire [22:0] stateReg
);

  // On reset or io_resetLfsr, state must be seeded to 23'h1DBFBC
  property p_lfsr_reset_seed;
    @(posedge clock)
    (reset || io_resetLfsr) |=>
      (stateReg == 23'h1DBFBC);
  endproperty

  // LFSR must never enter all-zero degenerate state
  property p_lfsr_nonzero;
    @(posedge clock) disable iff (reset || io_resetLfsr)
    io_increment |-> ##1 (stateReg != 23'h0);
  endproperty

  a_lfsr_reset_seed: assert property (p_lfsr_reset_seed)
    else $error("SVA FAIL: XC-08 LFSR not seeded to 23'h1DBFBC on reset");

  a_lfsr_nonzero: assert property (p_lfsr_nonzero)
    else $error("SVA FAIL: XC-08 LFSR entered degenerate all-zero state");

endmodule
// ============================================================
// Bind statements
// ============================================================
bind SBInitRequester sbinit_sva u_sbinit_sva (
  .clock       (clock),
  .reset       (reset),
  .currentState(currentState),
  .rxTxMode    (io_rxTxMode_0)
);
bind PatternWriter patternwriter_valid_framing_sva u_patternwriter_valid_framing_sva (
  .clock        (clock),
  .reset        (reset),
  .inProgress   (inProgress),
  .patternTypeReg(patternTypeReg),
  .bits_valid   (io_mbTxLaneIo_bits_valid_0)
);
bind PatternWriter patternwriter_sva u_patternwriter_sva (
  .clock          (clock),
  .reset          (reset),
  .req_valid      (io_interfaceIo_req_valid),
  .patternType    (io_interfaceIo_req_bits_patternType),
  .lfsr_pattern_0 (io_txLfsrCtrl_pattern_0),
  .lfsr_pattern_1 (io_txLfsrCtrl_pattern_1)
);
bind ParallelGaloisLFSR lfsr_sva u_lfsr_sva (
  .clock       (clock),
  .reset       (reset),
  .io_resetLfsr(io_resetLfsr),
  .io_increment(io_increment),
  .stateReg    (stateReg)
);

`endif
