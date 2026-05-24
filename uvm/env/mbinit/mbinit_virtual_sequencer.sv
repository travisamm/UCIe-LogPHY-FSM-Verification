`ifndef MBINIT_VIRTUAL_SEQUENCER_SV
`define MBINIT_VIRTUAL_SEQUENCER_SV

// ---------------------------------------------------------------------------
// mbinit_virtual_sequencer  (Pass 3)
// ---------------------------------------------------------------------------
// Holds one handle per drive channel so Pass 8 virtual sequences can drive the
// requester/responder RX lanes and the FSM-control bus directly through
// env.vseqr. In Pass 3 these are fed by the legacy adapter (via execute_item);
// the vseqr handles are populated by the env for future use.
//
// TODO(pass>=6): add a reset-injection sequencer handle here.
// ---------------------------------------------------------------------------
class mbinit_virtual_sequencer extends uvm_sequencer;
  `uvm_component_utils(mbinit_virtual_sequencer)

  mbinit_rx_sequencer   req_rx_seqr;
  mbinit_rx_sequencer   rsp_rx_seqr;
  mbinit_ctrl_sequencer ctrl_seqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass

`endif
