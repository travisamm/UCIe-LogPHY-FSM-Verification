`ifndef SBINIT_REQ_SEQUENCER_SV
`define SBINIT_REQ_SEQUENCER_SV

class sbinit_req_sequencer extends uvm_sequencer #(sbinit_req_transaction);
  `uvm_component_utils(sbinit_req_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass

`endif
