`ifndef MBINIT_RX_SEQUENCER_SV
`define MBINIT_RX_SEQUENCER_SV

// Sideband RX sequencer (one class, instantiated once per lane). In Pass 3 the
// legacy adapter feeds these via execute_item; Pass 8 migrates tests to drive
// them through the virtual sequencer directly.
class mbinit_rx_sequencer extends uvm_sequencer #(mbinit_rx_transaction);
  `uvm_component_utils(mbinit_rx_sequencer)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

`endif
