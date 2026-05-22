`ifndef SBINIT_STREAM_SVA_SV
`define SBINIT_STREAM_SVA_SV

// ===========================================================================
// sbinit_stream_sva
// ---------------------------------------------------------------------------
// Reusable, parameterized cycle-level assertion layer for ready/valid sideband
// streams. This is the home for *generic* stream invariants that the
// scoreboard (which now consumes protocol events, not raw cycles) should not
// own. It is kept separate from tb/logphy_sva.sv (which is read-only and binds
// DUT-internal signals) and is bound onto the SBINIT lane interfaces.
//
// First generic rule: payload stability under back-pressure.
//   While VALID is asserted and the beat has not been accepted (READY low), the
//   payload must remain stable until it is taken. The known RTL bug
//   (SBInit.scala assigns tx.bits.data inside `when(tx.ready)`) drives the
//   payload to 0 while valid is held, which this rule catches.
//
// Staged/gated: each instance is gated by an `en` input tied to the lane
// interface's stable_chk_en bit, which sbinit_base_test sets from the
// per-lane cfg flag. So the checker stays dormant during the known-bug period
// for every test except the back-pressure tests that opt in. Once the RTL is
// fixed, Pass 4 flips these on by default.
//
// TODO(pass3): protocol-specific SBINIT *persistence* assertions (e.g.
// Out-of-Reset "start and continue until detection/timeout/reset", repeated
// training-pattern behavior) belong in a separate SBINIT-specific checker,
// added once reset/timeout/abort boundaries are first-class. Keep them out of
// this generic stream-level rule.
// ===========================================================================
module sbinit_payload_stability_sva #(
  parameter int W = 128
) (
  input logic         clock,
  input logic         reset,
  input logic         valid,
  input logic         ready,
  input logic [W-1:0] data,
  input logic         en
);
  import uvm_pkg::*;

  // If a beat is offered but not accepted (valid && !ready), then on the next
  // cycle EITHER valid has dropped OR the payload is unchanged. Tolerating the
  // valid-drop avoids false fires on a legitimate offer end, while the $stable
  // term still catches the RTL bug: it drives data=0 during !ready and jumps to
  // the real payload at the accept boundary, which is a data change while valid
  // is held.
  property p_payload_stable_under_backpressure;
    @(posedge clock) disable iff (reset || !en)
    (valid && !ready) |=> (!valid || $stable(data));
  endproperty

  a_payload_stable: assert property (p_payload_stable_under_backpressure)
    else uvm_report_error("SBINIT_SVA",
      $sformatf("payload not stable under back-pressure: data changed while valid held and ready low (data=0x%0h)",
                data));

endmodule

// ---------------------------------------------------------------------------
// Bind the generic checker onto each lane's TX stream. `en` follows the
// interface's stable_chk_en bit (set per test from sbinit_env_cfg).
// ---------------------------------------------------------------------------
bind sb_req_if sbinit_payload_stability_sva #(.W(128)) u_req_tx_stability (
  .clock (clock),
  .reset (reset),
  .valid (tx_valid),
  .ready (tx_ready),
  .data  (tx_bits_data),
  .en    (stable_chk_en)
);

bind sb_rsp_if sbinit_payload_stability_sva #(.W(128)) u_rsp_tx_stability (
  .clock (clock),
  .reset (reset),
  .valid (tx_valid),
  .ready (tx_ready),
  .data  (tx_bits_data),
  .en    (stable_chk_en)
);

`endif
