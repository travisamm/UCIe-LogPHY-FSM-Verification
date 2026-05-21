`ifndef SBINIT_RSP_RX_SEQUENCER_SV
`define SBINIT_RSP_RX_SEQUENCER_SV

class sbinit_rsp_rx_sequencer extends uvm_sequencer #(sbinit_rsp_rx_transaction);
  `uvm_component_utils(sbinit_rsp_rx_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass

`endif
