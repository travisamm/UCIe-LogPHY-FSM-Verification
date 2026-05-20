`ifndef SBINIT_RSP_SEQUENCER_SV
`define SBINIT_RSP_SEQUENCER_SV

class sbinit_rsp_sequencer extends uvm_sequencer #(sbinit_rsp_transaction);
  `uvm_component_utils(sbinit_rsp_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass

`endif
