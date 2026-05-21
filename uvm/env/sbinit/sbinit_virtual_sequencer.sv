`ifndef SBINIT_VIRTUAL_SEQUENCER_SV
`define SBINIT_VIRTUAL_SEQUENCER_SV

class sbinit_virtual_sequencer extends uvm_sequencer;
  `uvm_component_utils(sbinit_virtual_sequencer)

  // One handle per drive channel across both lanes.
  sbinit_req_rx_sequencer  req_rx_seqr;
  sbinit_txready_sequencer req_txready_seqr;
  sbinit_rsp_rx_sequencer  rsp_rx_seqr;
  sbinit_txready_sequencer rsp_txready_seqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass

`endif
