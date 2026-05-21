`ifndef SBINIT_TXREADY_SEQUENCER_SV
`define SBINIT_TXREADY_SEQUENCER_SV

// Shared by both lanes (instantiated once per lane). The sequencer is
// interface-agnostic, so a single class serves req and rsp.
class sbinit_txready_sequencer extends uvm_sequencer #(sbinit_txready_transaction);
  `uvm_component_utils(sbinit_txready_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass

`endif
