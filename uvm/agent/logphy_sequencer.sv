`ifndef LOGPHY_SEQUENCER_SV
`define LOGPHY_SEQUENCER_SV

class logphy_sequencer extends uvm_sequencer #(logphy_transaction);
  `uvm_component_utils(logphy_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass
`endif
