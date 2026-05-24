`ifndef SBINIT_PERSISTENCE_SVA_SV
`define SBINIT_PERSISTENCE_SVA_SV

// ===========================================================================
// sbinit_persistence_sva
// ---------------------------------------------------------------------------
// SBINIT protocol-specific PERSISTENCE assertions, grounded in the UCIe 3.0
// specification (NOT in the RTL under test). These encode the spec's "start and
// continue ... until <exit>" requirements so they can actually catch an RTL
// that stops early, transmits the wrong thing, or fails to stop on detection.
//
// Spec references (UCIe Specification Revision 3.0, Section 4.5.3.2 "Sideband
// Initialization (SBINIT)"):
//   Step 1: "The UCIe Module must start and continue to send iterations of a
//            64-UI clock pattern (... toggling every UI, i.e., 1010...) ..."
//   Step 4: "... must stop sending data and clock on its sideband Transmitters
//            after four more iterations of 64-UI clock pattern and 32-UI low."
//   Step 5: "... continue to alternate ... for a total of 8 ms. Timeout occurs
//            after 8 ms. If a timeout occurs, the UCIe Module enters
//            TRAINERROR state."
//   Step 7: "... must start and continue to send {SBINIT Out of Reset} ...
//            until it detects the same message in its sideband Receivers or a
//            timeout occurs at 8 ms."
//   Step 8: "If {SBINIT Out of Reset} ... detection is successful ... the UCIe
//            Module stops sending the sideband message."
//
// Message encodings are spec-grounded. Confirmed against UCIe 3.0 Figure 7-3
// "Format for Messages without Data" (Phase0/Phase1 stacked as the 64-bit
// header) and Table 7-9:
//   opcode[4:0]      -> bits [4:0]    (Phase0)
//   msgcode[7:0]     -> bits [21:14]  (Phase0)
//   MsgSubcode[7:0]  -> bits [39:32]  (Phase1[7:0])
//   {SBINIT Out of Reset} : msgcode 0x91, subcode 0x00
//
// Kept separate from the generic ready/valid stream stability checker
// (sbinit_stream_sva) and from the reset checker (sbinit_reset_sva).
//
// TODO(spec-clarify): the following are NOT pinned down by Section 4.5.3.2 and
// are flagged for clarification with the spec/architecture owner:
//   (a) Clock-pattern serialization phase: "toggling every UI starting with 1"
//       maps to either 0x55..55 or 0xAA..AA in the 64-bit lane word depending on
//       the bit-serialization order defined in the Electrical/Sideband chapters
//       (Section 5/7), not here. We accept BOTH phases below; tighten once the
//       order is confirmed. The "32-UI low" framing (upper bits) is likewise not
//       constrained here, so this checker only constrains the lower 64 UI.
//   (b) RESOLVED: the message field positions (opcode [4:0], msgcode [21:14],
//       subcode [39:32]) are confirmed against Figure 7-3, and the elaborated
//       OoR/done message constants were verified to use this spec layout.
//   (c) Step 4's "stop after FOUR more iterations" exact count is not asserted
//       here: an "iteration" (64-UI pattern + 32-UI low) boundary is not cleanly
//       observable at the 128-bit lane-word granularity. Needs a spec-defined
//       iteration boundary (or a UI-accurate model) to assert precisely.
//   (d) The 8 ms timeout exit (Step 5/Step 7) is not modeled: it is far beyond
//       practical simulation length, so the persistence properties below treat
//       "detection" and "reset" as the exits. A directed timeout->TRAINERROR
//       proof needs a separate, time-scaled environment.
// ===========================================================================

checker sbinit_persistence_sva (
  input logic         clock,
  input logic         reset,
  input logic         sb_mode,    // sbRxTxMode: 0 = RAW (clock-pattern phase), 1 = PACKET
  input logic         tx_valid,   // requester TX (DUT -> partner)
  input logic [127:0] tx_data,
  input logic         rx_valid,   // requester RX (partner -> DUT)
  input logic [127:0] rx_data
);
  import uvm_pkg::*;

  // ---- spec-grounded message identity (UCIe 3.0 Table 7-9, Figure 7-3) ----
  // {SBINIT Out of Reset}: msgcode 0x91 @ [21:14], subcode 0x00 @ [39:32].
  //
  // Dual-layout note: sbinit_msg_pkg's decoder also accepts a second "create"
  // layout (msgcode @ [24:17], opcode widened to 8 bits) that the elaborated
  // SBMsgCreate path can theoretically produce. We deliberately match ONLY the
  // spec layout here because UCIe 3.0 Figure 7-3 defines exactly one encoding,
  // and the elaborated OoR message was verified to use that spec layout. If the
  // create layout is ever legitimately emitted this matcher would miss it - that
  // is intended (a non-spec encoding should not satisfy a spec-grounded check).
  function automatic bit is_oor(logic [127:0] d);
    return (d[21:14] == 8'h91) && (d[39:32] == 8'h00);
  endfunction

  // ---- spec-grounded clock pattern (UCIe 3.0 4.5.3.2 Step 1) ----
  function automatic bit is_clk_pattern(logic [127:0] d);
    // 64-UI pattern toggling every UI. See TODO(a) re: 0x55 vs 0xAA phase.
    return (d[63:0] == 64'h5555_5555_5555_5555) ||
           (d[63:0] == 64'hAAAA_AAAA_AAAA_AAAA);
  endfunction

  // -------------------------------------------------------------------------
  // Step 1: while in the clock-pattern phase (RAW sideband mode), any word the
  // DUT transmits must be the toggling 64-UI clock pattern - never anything
  // else. Catches a DUT that emits garbage / a message before the sideband is
  // functional.
  // -------------------------------------------------------------------------
  property p_clk_pattern_content;
    @(posedge clock) disable iff (reset)
    (!sb_mode && tx_valid) |-> is_clk_pattern(tx_data);
  endproperty
  a_clk_pattern_content: assert property (p_clk_pattern_content)
    else uvm_report_error("SBINIT_SVA",
      $sformatf("UCIe 4.5.3.2 Step1: non-clock-pattern word transmitted in RAW sideband mode (data=0x%032h)",
                tx_data));

  // -------------------------------------------------------------------------
  // Step 7: once the DUT starts sending {SBINIT Out of Reset}, it must continue
  // sending it until it detects the same message on its own receiver (or reset;
  // 8 ms timeout not modeled, see TODO(d)). I.e. it must not stop early. The
  // consequent allows the stop ONLY on the cycle detection is observed on RX,
  // which is exactly when the spec permits it to stop (Step 8).
  // -------------------------------------------------------------------------
  property p_oor_persist_until_detect;
    @(posedge clock) disable iff (reset)
    (tx_valid && is_oor(tx_data)) |=>
      ((tx_valid && is_oor(tx_data)) || (rx_valid && is_oor(rx_data)));
  endproperty
  a_oor_persist_until_detect: assert property (p_oor_persist_until_detect)
    else uvm_report_error("SBINIT_SVA",
      "UCIe 4.5.3.2 Step7: DUT stopped sending {SBINIT Out of Reset} before detecting it on its receiver");

  // -------------------------------------------------------------------------
  // Step 8: once {SBINIT Out of Reset} is detected on the receiver, the DUT
  // must stop sending it (it advances to the done handshake). Catches a DUT
  // that keeps sending OoR after the partner has been detected.
  //
  // The antecedent triggers on the detection itself (OoR seen on RX), not on a
  // simultaneous TX, because a correct DUT drops its OoR TX on the very cycle it
  // detects - so requiring TX still high at detection would make the property
  // vacuous. We require that the cycle AFTER detection, OoR is no longer being
  // transmitted.
  // -------------------------------------------------------------------------
  property p_oor_stop_after_detect;
    @(posedge clock) disable iff (reset)
    (rx_valid && is_oor(rx_data)) |=> !(tx_valid && is_oor(tx_data));
  endproperty
  a_oor_stop_after_detect: assert property (p_oor_stop_after_detect)
    else uvm_report_error("SBINIT_SVA",
      "UCIe 4.5.3.2 Step8: DUT kept sending {SBINIT Out of Reset} after detecting it on its receiver");

endchecker

// ---------------------------------------------------------------------------
// Bind into the testbench top so the checker can see the requester lane
// (sb_req_if) and the FSM-control mode (sb_ctrl_if) together. The DUT port
// connections in logphy_tb_top are not touched by this bind.
// ---------------------------------------------------------------------------
bind logphy_tb_top sbinit_persistence_sva u_sbinit_persistence (
  .clock    (clock),
  .reset    (reset),
  .sb_mode  (ctrl_if.sbRxTxMode),
  .tx_valid (req_if.tx_valid),
  .tx_data  (req_if.tx_bits_data),
  .rx_valid (req_if.rx_valid),
  .rx_data  (req_if.rx_bits_data)
);

// ===========================================================================
// sbinit_rsp_persistence_sva
// ---------------------------------------------------------------------------
// Responder-lane protocol persistence (UCIe 3.0 Section 4.5.3.2 Step 10). The
// responder answers a received {SBINIT done req} with {SBINIT done resp}. Once
// it begins transmitting the {done resp}, it must hold that response until the
// beat is accepted (tx_ready), then stop - it may neither retract the offer
// before acceptance nor keep re-sending it afterward.
//
// This is the responder analog of the requester's Out-of-Reset persistence: the
// "exit" event here is acceptance (the handshake completing) rather than a
// received message. Bound onto the responder lane only - no cross-interface
// signals are needed.
//
// This is protocol persistence (the response is held until the handshake
// completes), distinct from the generic ready/valid payload-stability rule in
// sbinit_stream_sva. Under the current RTL back-pressure bug the offered beat is
// corrupted to zero, so is_done_resp() is false during that window and these
// properties are vacuous there (that failure is owned by the stream SVA and the
// reference model); they become fully active once the payload is held stable.
// ===========================================================================
checker sbinit_rsp_persistence_sva (
  input logic         clock,
  input logic         reset,
  input logic         tx_valid,
  input logic         tx_ready,
  input logic [127:0] tx_data
);
  import uvm_pkg::*;

  // {SBINIT done resp}: msgcode 0x9A @ [21:14], subcode 0x01 @ [39:32]
  // (UCIe 3.0 Figure 7-3 / Table 7-9; same spec layout as is_oor above).
  function automatic bit is_done_resp(logic [127:0] d);
    return (d[21:14] == 8'h9A) && (d[39:32] == 8'h01);
  endfunction

  // Persist: while offering {done resp} and not yet accepted (ready low), the
  // responder must still be offering it next cycle - no premature retraction.
  property p_done_resp_persist_until_accept;
    @(posedge clock) disable iff (reset)
    (tx_valid && is_done_resp(tx_data) && !tx_ready) |=>
      (tx_valid && is_done_resp(tx_data));
  endproperty
  a_done_resp_persist: assert property (p_done_resp_persist_until_accept)
    else uvm_report_error("SBINIT_SVA",
      "UCIe 4.5.3.2 Step10: responder retracted {done resp} before it was accepted");

  // Stop: once the {done resp} is accepted, the responder stops sending it.
  property p_done_resp_stop_after_accept;
    @(posedge clock) disable iff (reset)
    (tx_valid && is_done_resp(tx_data) && tx_ready) |=>
      !(tx_valid && is_done_resp(tx_data));
  endproperty
  a_done_resp_stop: assert property (p_done_resp_stop_after_accept)
    else uvm_report_error("SBINIT_SVA",
      "UCIe 4.5.3.2 Step10: responder kept sending {done resp} after it was accepted");

endchecker

bind sb_rsp_if sbinit_rsp_persistence_sva u_sbinit_rsp_persistence (
  .clock    (clock),
  .reset    (reset),
  .tx_valid (tx_valid),
  .tx_ready (tx_ready),
  .tx_data  (tx_bits_data)
);

`endif
