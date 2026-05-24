`ifndef MBINIT_CTRL_SEQUENCER_SV
`define MBINIT_CTRL_SEQUENCER_SV

// FSM-control sequencer (start + local PHY settings).
class mbinit_ctrl_sequencer extends uvm_sequencer #(mbinit_ctrl_transaction);
  `uvm_component_utils(mbinit_ctrl_sequencer)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

`endif
