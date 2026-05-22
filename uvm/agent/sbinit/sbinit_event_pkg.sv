`ifndef SBINIT_EVENT_PKG_SV
`define SBINIT_EVENT_PKG_SV

// ---------------------------------------------------------------------------
// sbinit_event_pkg  (Pass 1: event/decoder foundation)
// ---------------------------------------------------------------------------
// The SBINIT template direction (Route 2) is: monitors publish *protocol
// events*, scoreboards/coverage *consume events*, and cycle-level stream
// invariants live in reusable SVA. This package is the shared vocabulary for
// that contract:
//
//   * sbinit_event   - one common observed type carried on analysis ports
//   * sbinit_decoder - centralized, layout-aware classification of lane words
//
// Pass 1 is purely additive: nothing here is wired into the live monitors,
// scoreboard, or coverage yet (that is Pass 2). The only consumer today is the
// focused decoder unit test (test_sbinit_decode).
//
// Why a separate package (not sbinit_msg_pkg): keep the on-the-wire message
// format (sbinit_msg_pkg) separate from the observation/event model so each can
// evolve independently and so the event model can pull in UVM (uvm_object,
// factory) without forcing that dependency on the pure wire-format package.
// ---------------------------------------------------------------------------

`include "sbinit_msg_pkg.sv"

package sbinit_event_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import sbinit_msg_pkg::*;

  // -------------------------------------------------------------------------
  // Event vocabulary
  // -------------------------------------------------------------------------
  // What was observed. Lane events (CLK_PATTERN / OUT_OF_RESET / DONE_* /
  // UNKNOWN) come from decoding a lane word; the STOP / MODE / FSM kinds are
  // synthesized by a monitor from edges, not decoded from a word. The decoder
  // in this package only ever produces the lane-word subset.
  typedef enum {
    SB_EVT_CLK_PATTERN,       // a 64-UI clock-pattern word was observed
    SB_EVT_CLK_PATTERN_STOP,  // a lane stopped emitting the clock pattern
    SB_EVT_OUT_OF_RESET,      // SBINIT Out-of-Reset message
    SB_EVT_DONE_REQ,          // SBINIT Done Req message
    SB_EVT_DONE_RESP,         // SBINIT Done Resp message
    SB_EVT_MODE_FUNCTIONAL,   // sbRxTxMode transitioned 0 -> 1
    SB_EVT_FSM_DONE,          // fsmCtrl_done asserted
    SB_EVT_FSM_ERROR,         // fsmCtrl_error asserted
    SB_EVT_RESET_ASSERTED,    // DUT reset went active (boundary)
    SB_EVT_RESET_DEASSERTED,  // DUT reset released (new attempt begins)
    SB_EVT_UNKNOWN            // valid lane activity that decoded to nothing known
  } sbinit_evt_kind_e;

  // Which producer the event came from.
  typedef enum {
    SB_SRC_REQ_LANE,  // requester sideband lane monitor
    SB_SRC_RSP_LANE,  // responder sideband lane monitor
    SB_SRC_CTRL,      // FSM-control monitor (mode / done / error)
    SB_SRC_RESET      // reset monitor (single reset-event source)
  } sbinit_evt_src_e;

  // Direction of a lane event, from the testbench's point of view.
  typedef enum {
    SB_DIR_TX,  // DUT -> partner (the DUT transmitted)
    SB_DIR_RX,  // partner -> DUT (the TB transmitted)
    SB_DIR_NA   // not a lane direction (control events)
  } sbinit_evt_dir_e;

  // Lifecycle phase of a transfer. OFFERED = valid asserted but not yet
  // accepted (ready low); ACCEPTED = valid && ready in the same cycle;
  // OBSERVED = a point-in-time observation with no offer/accept distinction
  // (clock pattern, control edges). Pass 2 emits OFFERED/ACCEPTED pairs where
  // the TX handshake lifecycle matters; Pass 1 just defines the field.
  typedef enum {
    SB_PHASE_OBSERVED,
    SB_PHASE_OFFERED,
    SB_PHASE_ACCEPTED
  } sbinit_evt_phase_e;

  // Which on-the-wire layout decoded. The RTL can emit either, depending on the
  // code path (see sbinit_msg_pkg): COMPARE is the spec-aligned slice layout;
  // CREATE is the SBMsgCreate layout where the opcode is widened to 8 bits,
  // shifting message code / subcode up by 3 bits.
  typedef enum {
    SB_LAYOUT_NONE,     // not a decoded message (clock pattern / unknown / control)
    SB_LAYOUT_COMPARE,  // spec-aligned: opcode[4:0], mc[21:14], sc[39:32]
    SB_LAYOUT_CREATE    // widened opcode: opcode[7:0], mc[24:17], sc[42:35]
  } sbinit_evt_layout_e;

  // -------------------------------------------------------------------------
  // sbinit_event - the common observed type
  // -------------------------------------------------------------------------
  class sbinit_event extends uvm_object;

    // Classification.
    sbinit_evt_kind_e   kind   = SB_EVT_UNKNOWN;
    sbinit_evt_src_e    src    = SB_SRC_REQ_LANE;
    sbinit_evt_dir_e    dir    = SB_DIR_NA;
    sbinit_evt_phase_e  phase  = SB_PHASE_OBSERVED;
    sbinit_evt_layout_e layout = SB_LAYOUT_NONE;

    // Evidence: the raw observed lane word (preserved for diagnostics even when
    // decode fails) plus the decoded fields per the matched layout.
    logic [127:0] raw     = 128'h0;
    bit  [4:0]    opcode  = 5'h0;
    bit  [7:0]    msg_code = 8'h0;
    bit  [7:0]    subcode = 8'h0;
    bit  [63:0]   payload = 64'h0;

    // Bookkeeping. tstamp is sim time; seq_num is a per-source monotonically
    // increasing counter; lifecycle_id ties an OFFERED event to its later
    // ACCEPTED event for the same observed transfer (0 = unused).
    real         tstamp       = 0.0;
    int unsigned seq_num      = 0;
    int unsigned lifecycle_id = 0;

    `uvm_object_utils_begin(sbinit_event)
      `uvm_field_enum(sbinit_evt_kind_e,   kind,   UVM_ALL_ON)
      `uvm_field_enum(sbinit_evt_src_e,    src,    UVM_ALL_ON)
      `uvm_field_enum(sbinit_evt_dir_e,    dir,    UVM_ALL_ON)
      `uvm_field_enum(sbinit_evt_phase_e,  phase,  UVM_ALL_ON)
      `uvm_field_enum(sbinit_evt_layout_e, layout, UVM_ALL_ON)
      `uvm_field_int (raw,          UVM_ALL_ON | UVM_HEX)
      `uvm_field_int (opcode,       UVM_ALL_ON | UVM_HEX)
      `uvm_field_int (msg_code,     UVM_ALL_ON | UVM_HEX)
      `uvm_field_int (subcode,      UVM_ALL_ON | UVM_HEX)
      `uvm_field_int (payload,      UVM_ALL_ON | UVM_HEX)
      `uvm_field_real(tstamp,       UVM_ALL_ON)
      `uvm_field_int (seq_num,      UVM_ALL_ON | UVM_DEC)
      `uvm_field_int (lifecycle_id, UVM_ALL_ON | UVM_DEC)
    `uvm_object_utils_end

    function new(string name = "sbinit_event");
      super.new(name);
    endfunction

    function string convert2string();
      return $sformatf(
        "%s src=%s dir=%s phase=%s layout=%s mc=0x%02h sc=0x%02h seq=%0d lid=%0d raw=0x%032h",
        kind.name(), src.name(), dir.name(), phase.name(), layout.name(),
        msg_code, subcode, seq_num, lifecycle_id, raw);
    endfunction

  endclass

  // -------------------------------------------------------------------------
  // sbinit_decoder - centralized, layout-aware classification of lane words
  // -------------------------------------------------------------------------
  // Single source of truth for turning a raw 128-bit lane word into a partially
  // populated sbinit_event (kind / layout / decoded fields / raw). Monitors fill
  // in the contextual fields (src / dir / phase / seq_num / lifecycle_id /
  // tstamp) after calling decode_lane_word().
  //
  // Notes:
  //   * Undecodable valid activity is classified SB_EVT_UNKNOWN (never dropped),
  //     so the scoreboard can choose to fail on it (Pass 2 policy).
  //   * sbinit_msg_pkg::sbinit_sb_msg::unpack() only handles the COMPARE layout;
  //     this decoder is the layout-aware replacement and records which matched.
  class sbinit_decoder;

    static function bit is_clock_pattern(logic [127:0] data);
      return (data === SBINIT_CLK_PATTERN_A)  ||
             (data === SBINIT_CLK_PATTERN_5)  ||
             (data === SBINIT_CLK_PATTERN_5A) ||
             (data === SBINIT_CLK_PATTERN_A5);
    endfunction

    // Which layout (if any) carries this msg_code/subcode pair.
    static function sbinit_evt_layout_e layout_of(logic [127:0] data,
                                                  bit [7:0] mc,
                                                  bit [7:0] sc);
      if (is_sb_msg_compare_layout(data, mc, sc)) return SB_LAYOUT_COMPARE;
      if (is_sb_msg_create_layout (data, mc, sc)) return SB_LAYOUT_CREATE;
      return SB_LAYOUT_NONE;
    endfunction

    // Populate ev.opcode/msg_code/subcode/payload per the matched layout. The
    // CREATE payload slice is the COMPARE slice shifted up 3 bits (inferred from
    // the same +3 shift the opcode/code/subcode fields take).
    static function void extract_fields(logic [127:0]       data,
                                        sbinit_evt_layout_e layout,
                                        sbinit_event        ev);
      case (layout)
        SB_LAYOUT_COMPARE: begin
          ev.opcode   = data[4:0];
          ev.msg_code = data[21:14];
          ev.subcode  = data[39:32];
          ev.payload  = data[103:40];
        end
        SB_LAYOUT_CREATE: begin
          ev.opcode   = data[4:0];     // low 5 bits of the widened 8-bit opcode
          ev.msg_code = data[24:17];
          ev.subcode  = data[42:35];
          ev.payload  = data[106:43];  // inferred: COMPARE payload shifted +3
        end
        default: begin
          ev.opcode = 5'h0; ev.msg_code = 8'h0; ev.subcode = 8'h0; ev.payload = 64'h0;
        end
      endcase
    endfunction

    // Classify a raw lane word. Returns a fresh sbinit_event with kind / layout
    // / decoded fields / raw set; contextual fields are left at defaults for the
    // caller to fill.
    static function sbinit_event decode_lane_word(logic [127:0] data);
      sbinit_event        ev;
      sbinit_evt_layout_e lay;

      ev     = sbinit_event::type_id::create("sb_evt");
      ev.raw = data;

      if (is_clock_pattern(data)) begin
        ev.kind   = SB_EVT_CLK_PATTERN;
        ev.layout = SB_LAYOUT_NONE;
        return ev;
      end

      lay = layout_of(data, SBINIT_MC_OUT_OF_RESET, SBINIT_SC_OOR);
      if (lay != SB_LAYOUT_NONE) begin
        ev.kind = SB_EVT_OUT_OF_RESET; ev.layout = lay;
        extract_fields(data, lay, ev);
        return ev;
      end

      lay = layout_of(data, SBINIT_MC_DONE_REQ, SBINIT_SC_DONE);
      if (lay != SB_LAYOUT_NONE) begin
        ev.kind = SB_EVT_DONE_REQ; ev.layout = lay;
        extract_fields(data, lay, ev);
        return ev;
      end

      lay = layout_of(data, SBINIT_MC_DONE_RESP, SBINIT_SC_DONE);
      if (lay != SB_LAYOUT_NONE) begin
        ev.kind = SB_EVT_DONE_RESP; ev.layout = lay;
        extract_fields(data, lay, ev);
        return ev;
      end

      // Valid activity that matched nothing known: keep it, flag it.
      ev.kind   = SB_EVT_UNKNOWN;
      ev.layout = SB_LAYOUT_NONE;
      return ev;
    endfunction

  endclass

endpackage

`endif
