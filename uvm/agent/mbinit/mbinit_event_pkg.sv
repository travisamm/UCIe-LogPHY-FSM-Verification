`ifndef MBINIT_EVENT_PKG_SV
`define MBINIT_EVENT_PKG_SV

// ===========================================================================
// mbinit_event_pkg  (Pass 1: event/decoder foundation)
// ---------------------------------------------------------------------------
// The MBINIT refactor follows the SBINIT template (Route 2): monitors publish
// *protocol events*, scoreboard/coverage *consume events*, and cycle-level
// stream invariants live in reusable SVA. This package is the shared vocabulary
// for that contract:
//
//   * mbinit_event   - one common observed type carried on analysis ports
//   * mbinit_decoder - centralized classification of sideband lane words
//
// Pass 4 wires the producer side of this event stream (lane / control / reset
// / service / lane-control monitors -> mbinit_event_audit) in shadow mode; the
// legacy mbinit_monitor + transaction scoreboard + coverage remain authoritative
// until Pass 5. The decode-unit test (test_mbinit_decode) also consumes this.
//
// Why separate from mbinit_msg_pkg: keep the on-the-wire message format
// (mbinit_msg_pkg, no UVM) separate from the observation/event model (this
// package, depends on UVM) so each evolves independently.
//
// MBINIT carries far more than two sideband messages, so the event model is
// two-level:
//   * evt_kind  - high-level category of the observation (SB message, state
//                 transition, negotiated params, a service handshake, reset...)
//   * msg_kind + role - for SB-message events, *which* message and whether it
//                 came from the requester (msgCode 0xA5) or responder (0xAA).
// The event also carries "evidence" fields (currentState, pattern type, point-
// test results, lane-control snapshot, negotiated params) so a single stream
// can feed every requirement check without re-sampling the bus.
// ===========================================================================

`include "mbinit_msg_pkg.sv"

package mbinit_event_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import mbinit_msg_pkg::*;

  // -------------------------------------------------------------------------
  // High-level observation category.
  // -------------------------------------------------------------------------
  typedef enum {
    MB_EVT_SB_MSG,          // a decoded sideband message (see msg_kind/role)
    MB_EVT_STATE,           // currentState transition (evidence: state)
    MB_EVT_NEG_PARAMS,      // negotiatedPhySettings.valid (evidence: rate/mode/phase)
    MB_EVT_INTEROP_FAIL,    // interoperableParamsNotFound asserted
    MB_EVT_PATTERN_WRITER,  // patternWriter request (evidence: pattern_type)
    MB_EVT_PATTERN_READER,  // patternReader request/response (evidence: pattern_type/lanes)
    MB_EVT_PTTEST,          // Tx point-test start/result (evidence: pt_results)
    MB_EVT_CAL,             // mbInitCalStart/Done handshake edge
    MB_EVT_LANE_CTRL,       // mbLaneCtrlIo snapshot (evidence: lane-ctrl fields)
    MB_EVT_TXWIDTH_CHANGED, // io_txWidthChanged pulse (REPAIRMB width degrade)
    MB_EVT_FSM_DONE,        // fsmCtrl_done asserted
    MB_EVT_FSM_ERROR,       // fsmCtrl_error asserted
    MB_EVT_RESET_ASSERTED,  // DUT reset went active (boundary)
    MB_EVT_RESET_DEASSERTED,// DUT reset released (new attempt begins)
    MB_EVT_UNKNOWN          // valid lane activity that decoded to nothing known
  } mbinit_evt_kind_e;

  // -------------------------------------------------------------------------
  // For MB_EVT_SB_MSG: which MBINIT message this lane word carries.
  // -------------------------------------------------------------------------
  typedef enum {
    MB_MSG_NONE,
    MB_MSG_PARAM,
    MB_MSG_CAL,
    MB_MSG_RCLK_INIT,
    MB_MSG_RCLK_RES,
    MB_MSG_RCLK_DONE,
    MB_MSG_RVAL_INIT,
    MB_MSG_RVAL_RES,
    MB_MSG_RVAL_DONE,
    MB_MSG_LR_INIT,
    MB_MSG_LR_CLR,
    MB_MSG_LR_RES,
    MB_MSG_LR_DONE,
    MB_MSG_RM_START,
    MB_MSG_RM_APPLY,
    MB_MSG_RM_END,
    MB_MSG_UNKNOWN
  } mbinit_msg_kind_e;

  // Requester (msgCode 0xA5) vs responder (0xAA) role of a decoded message.
  typedef enum {
    MB_ROLE_NONE,
    MB_ROLE_REQ,
    MB_ROLE_RESP
  } mbinit_role_e;

  // Which producer the event came from.
  typedef enum {
    MB_SRC_REQ_LANE,        // requester sideband lane monitor
    MB_SRC_RSP_LANE,        // responder sideband lane monitor
    MB_SRC_CTRL,            // FSM-control / state monitor
    MB_SRC_PARAMS,          // negotiated-params monitor
    MB_SRC_PATTERN_WRITER,  // pattern-writer service monitor
    MB_SRC_PATTERN_READER,  // pattern-reader service monitor
    MB_SRC_PTTEST_REQ,      // Tx point-test requester-side service monitor
    MB_SRC_PTTEST_RSP,      // Tx point-test responder-side service monitor
    MB_SRC_CAL,             // calibration service monitor
    MB_SRC_LANE_CTRL,       // mbLaneCtrlIo monitor
    MB_SRC_RESET            // reset monitor
  } mbinit_evt_src_e;

  // Direction of a lane event, from the testbench's point of view.
  typedef enum {
    MB_DIR_TX,  // DUT -> partner (the DUT transmitted)
    MB_DIR_RX,  // partner -> DUT (the TB transmitted)
    MB_DIR_NA   // not a lane direction (control / service / state)
  } mbinit_evt_dir_e;

  // Lifecycle phase of a transfer. OFFERED = valid asserted but not yet
  // accepted (ready low); ACCEPTED = valid && ready same cycle; OBSERVED = a
  // point-in-time observation (state edges, service pulses). Pass 4 emits
  // OFFERED/ACCEPTED where the TX handshake lifecycle matters.
  typedef enum {
    MB_PHASE_OBSERVED,
    MB_PHASE_OFFERED,
    MB_PHASE_ACCEPTED
  } mbinit_evt_phase_e;

  // Service-handshake edge (Pass 4). Lane transfer lifecycle stays on `phase`;
  // service handshakes use this to label which edge of the cal / pattern-writer
  // / pattern-reader / point-test handshake an event represents. NONE for non-
  // service events (lane / state / reset / lane-ctrl).
  //   REQ    : service request edge      (e.g. PW req_valid offered/accepted)
  //   RESP   : service response edge     (reserved for symmetric req/resp)
  //   START  : start-side pulse          (cal_start, pttest start)
  //   DONE   : completion pulse          (cal_done, resp_complete, req_done, pttest done)
  //   RESULT : result-bearing pulse      (PR resp_valid, PTtest results_valid)
  //   CLEAR  : substate-clear pulse      (PR req_clear)
  typedef enum {
    MB_SVC_NONE,
    MB_SVC_REQ,
    MB_SVC_RESP,
    MB_SVC_START,
    MB_SVC_DONE,
    MB_SVC_RESULT,
    MB_SVC_CLEAR
  } mbinit_evt_svc_e;

  // Which on-the-wire layout decoded. MBINIT uses only the spec compare layout
  // today; the enum keeps the SBINIT-parallel shape for forward-compat.
  typedef enum {
    MB_LAYOUT_NONE,    // not a decoded message
    MB_LAYOUT_COMPARE  // spec: opcode[4:0], mc[21:14], sc[39:32]
  } mbinit_evt_layout_e;

  // -------------------------------------------------------------------------
  // mbinit_event - the common observed type
  // -------------------------------------------------------------------------
  class mbinit_event extends uvm_object;

    // Classification.
    mbinit_evt_kind_e   kind     = MB_EVT_UNKNOWN;
    mbinit_msg_kind_e   msg_kind = MB_MSG_NONE;
    mbinit_role_e       role     = MB_ROLE_NONE;
    mbinit_evt_src_e    src      = MB_SRC_REQ_LANE;
    mbinit_evt_dir_e    dir      = MB_DIR_NA;
    mbinit_evt_phase_e  phase    = MB_PHASE_OBSERVED;
    mbinit_evt_layout_e layout   = MB_LAYOUT_NONE;
    mbinit_evt_svc_e    svc_kind = MB_SVC_NONE;   // Pass 4: service-edge label

    // Decoded sideband-message fields (valid when kind == MB_EVT_SB_MSG).
    logic [127:0] raw      = 128'h0;
    bit  [4:0]    opcode   = 5'h0;
    bit  [7:0]    msg_code = 8'h0;
    bit  [7:0]    subcode  = 8'h0;
    bit  [2:0]    msg_info = 3'h0;
    bit  [63:0]   data     = 64'h0;

    // Evidence fields (populated by the producing monitor as relevant).
    bit  [2:0]    state          = 3'h0;   // currentState at observation
    bit  [1:0]    pattern_type   = 2'h0;   // patternWriter/Reader type
    bit  [15:0]   pt_results     = 16'h0;  // Tx point-test per-lane bits
    bit  [15:0]   pr_per_lane    = 16'h0;  // PatternReader resp per-lane bits
    bit           pr_aggregate   = 1'b0;   // PatternReader resp aggregate status
    bit  [3:0]    neg_data_rate  = 4'h0;   // negotiated maxDataRate
    bit           neg_clock_mode = 1'b0;   // negotiated clockMode
    bit           neg_clock_phase= 1'b0;   // negotiated clockPhase
    // Lane-control snapshot (XC-05). Packed En vector: 1=enabled/active.
    bit  [15:0]   lc_tx_data_en  = 16'h0;
    bit           lc_tx_clk_en   = 1'b0;
    bit           lc_tx_valid_en = 1'b0;
    bit           lc_tx_track_en = 1'b0;
    bit  [15:0]   lc_rx_data_en  = 16'h0;
    bit           lc_rx_clk_en   = 1'b0;
    bit           lc_rx_valid_en = 1'b0;
    bit           lc_rx_track_en = 1'b0;

    // Bookkeeping. tstamp is sim time; seq_num is a per-source counter;
    // lifecycle_id ties an OFFERED event to its later ACCEPTED event.
    real         tstamp       = 0.0;
    int unsigned seq_num      = 0;
    int unsigned lifecycle_id = 0;

    `uvm_object_utils_begin(mbinit_event)
      `uvm_field_enum(mbinit_evt_kind_e,   kind,     UVM_ALL_ON)
      `uvm_field_enum(mbinit_msg_kind_e,   msg_kind, UVM_ALL_ON)
      `uvm_field_enum(mbinit_role_e,       role,     UVM_ALL_ON)
      `uvm_field_enum(mbinit_evt_src_e,    src,      UVM_ALL_ON)
      `uvm_field_enum(mbinit_evt_dir_e,    dir,      UVM_ALL_ON)
      `uvm_field_enum(mbinit_evt_phase_e,  phase,    UVM_ALL_ON)
      `uvm_field_enum(mbinit_evt_layout_e, layout,   UVM_ALL_ON)
      `uvm_field_enum(mbinit_evt_svc_e,    svc_kind, UVM_ALL_ON)
      `uvm_field_int (raw,            UVM_ALL_ON | UVM_HEX)
      `uvm_field_int (opcode,         UVM_ALL_ON | UVM_HEX)
      `uvm_field_int (msg_code,       UVM_ALL_ON | UVM_HEX)
      `uvm_field_int (subcode,        UVM_ALL_ON | UVM_HEX)
      `uvm_field_int (msg_info,       UVM_ALL_ON | UVM_HEX)
      `uvm_field_int (data,           UVM_ALL_ON | UVM_HEX)
      `uvm_field_int (state,          UVM_ALL_ON | UVM_DEC)
      `uvm_field_int (pattern_type,   UVM_ALL_ON | UVM_HEX)
      `uvm_field_int (pt_results,     UVM_ALL_ON | UVM_HEX)
      `uvm_field_int (pr_per_lane,    UVM_ALL_ON | UVM_HEX)
      `uvm_field_int (pr_aggregate,   UVM_ALL_ON)
      `uvm_field_int (neg_data_rate,  UVM_ALL_ON | UVM_HEX)
      `uvm_field_int (neg_clock_mode, UVM_ALL_ON)
      `uvm_field_int (neg_clock_phase,UVM_ALL_ON)
      `uvm_field_int (lc_tx_data_en,  UVM_ALL_ON | UVM_HEX)
      `uvm_field_int (lc_rx_data_en,  UVM_ALL_ON | UVM_HEX)
      `uvm_field_real(tstamp,         UVM_ALL_ON)
      `uvm_field_int (seq_num,        UVM_ALL_ON | UVM_DEC)
      `uvm_field_int (lifecycle_id,   UVM_ALL_ON | UVM_DEC)
    `uvm_object_utils_end

    function new(string name = "mbinit_event");
      super.new(name);
    endfunction

    function string convert2string();
      if (kind == MB_EVT_SB_MSG)
        return $sformatf(
          "%s msg=%s role=%s src=%s dir=%s phase=%s mc=0x%02h sc=0x%02h info=0x%01h seq=%0d lid=%0d raw=0x%032h",
          kind.name(), msg_kind.name(), role.name(), src.name(), dir.name(),
          phase.name(), msg_code, subcode, msg_info, seq_num, lifecycle_id, raw);
      else
        return $sformatf(
          "%s src=%s dir=%s phase=%s svc=%s state=%0d ptype=%0h pt=0x%04h pr=0x%04h/%0b seq=%0d",
          kind.name(), src.name(), dir.name(), phase.name(), svc_kind.name(),
          state, pattern_type, pt_results, pr_per_lane, pr_aggregate, seq_num);
    endfunction

  endclass

  // -------------------------------------------------------------------------
  // mbinit_decoder - centralized classification of sideband lane words
  // -------------------------------------------------------------------------
  // Single source of truth for turning a raw 128-bit sideband word into a
  // partially populated mbinit_event (kind / msg_kind / role / layout / decoded
  // fields / raw). Lane monitors fill in contextual fields (src / dir / phase /
  // seq_num / lifecycle_id / tstamp / evidence) after calling this.
  //
  // A valid word that is not a recognizable MBINIT message is classified
  // MB_EVT_UNKNOWN (never dropped), so the scoreboard can choose to fail on it.
  class mbinit_decoder;

    // msgCode -> role.
    static function mbinit_role_e role_of(bit [7:0] mc);
      case (mc)
        MBINIT_MC_REQ : return MB_ROLE_REQ;
        MBINIT_MC_RESP: return MB_ROLE_RESP;
        default       : return MB_ROLE_NONE;
      endcase
    endfunction

    // subcode -> message identity (role-independent).
    static function mbinit_msg_kind_e msg_of(bit [7:0] sc);
      case (sc)
        MBINIT_SC_PARAM    : return MB_MSG_PARAM;
        MBINIT_SC_CAL      : return MB_MSG_CAL;
        MBINIT_SC_RCLK_INIT: return MB_MSG_RCLK_INIT;
        MBINIT_SC_RCLK_RES : return MB_MSG_RCLK_RES;
        MBINIT_SC_RCLK_DONE: return MB_MSG_RCLK_DONE;
        MBINIT_SC_RVAL_INIT: return MB_MSG_RVAL_INIT;
        MBINIT_SC_RVAL_RES : return MB_MSG_RVAL_RES;
        MBINIT_SC_RVAL_DONE: return MB_MSG_RVAL_DONE;
        MBINIT_SC_LR_INIT  : return MB_MSG_LR_INIT;
        MBINIT_SC_LR_CLR   : return MB_MSG_LR_CLR;
        MBINIT_SC_LR_RES   : return MB_MSG_LR_RES;
        MBINIT_SC_LR_DONE  : return MB_MSG_LR_DONE;
        MBINIT_SC_RM_START : return MB_MSG_RM_START;
        MBINIT_SC_RM_APPLY : return MB_MSG_RM_APPLY;
        MBINIT_SC_RM_END   : return MB_MSG_RM_END;
        default            : return MB_MSG_UNKNOWN;
      endcase
    endfunction

    // Classify a raw sideband word. Returns a fresh mbinit_event with kind /
    // msg_kind / role / layout / decoded fields / raw set; contextual and
    // evidence fields are left at defaults for the caller to populate.
    static function mbinit_event decode_lane_word(logic [127:0] data);
      mbinit_event      ev;
      bit [4:0]         op;
      bit [7:0]         mc, sc;
      mbinit_role_e     r;
      mbinit_msg_kind_e mk;

      ev     = mbinit_event::type_id::create("mb_evt");
      ev.raw = data;
      op = mb_op(data);
      mc = mb_mc(data);
      sc = mb_sc(data);

      // Must be one of the two MBINIT opcodes, a known msgCode, and a known
      // subcode; otherwise it is valid-but-unrecognized.
      r  = role_of(mc);
      mk = msg_of(sc);
      if (((op == MBINIT_OP_NODATA) || (op == MBINIT_OP_64DATA)) &&
          (r != MB_ROLE_NONE) && (mk != MB_MSG_UNKNOWN)) begin
        ev.kind     = MB_EVT_SB_MSG;
        ev.msg_kind = mk;
        ev.role     = r;
        ev.layout   = MB_LAYOUT_COMPARE;
        ev.opcode   = op;
        ev.msg_code = mc;
        ev.subcode  = sc;
        ev.msg_info = mb_info(data);
        ev.data     = mb_data(data);
        return ev;
      end

      // Valid activity that matched nothing known: keep it, flag it.
      ev.kind   = MB_EVT_UNKNOWN;
      ev.layout = MB_LAYOUT_NONE;
      return ev;
    endfunction

  endclass

endpackage

`endif
