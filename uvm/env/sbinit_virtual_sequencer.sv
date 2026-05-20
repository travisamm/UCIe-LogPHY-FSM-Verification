`ifndef SBINIT_VIRTUAL_SEQUENCER_SV
`define SBINIT_VIRTUAL_SEQUENCER_SV

class sbinit_virtual_sequencer extends uvm_sequencer;
  `uvm_component_utils(sbinit_virtual_sequencer)

  sbinit_req_sequencer req_seqr;
  sbinit_rsp_sequencer rsp_seqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass

`endif
