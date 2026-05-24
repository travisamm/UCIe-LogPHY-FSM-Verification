`ifndef SBINIT_RSP_RX_TRANSACTION_SV
`define SBINIT_RSP_RX_TRANSACTION_SV

// ---------------------------------------------------------------------------
// sbinit_rsp_rx_transaction
// ---------------------------------------------------------------------------
// Drive item for the responder RX channel: partner -> DUT sideband data.
// tx_ready is on the independent tx-ready channel (sbinit_txready_transaction).
// ---------------------------------------------------------------------------
class sbinit_rsp_rx_transaction extends uvm_sequence_item;
  rand logic         rx_valid;
  rand logic [127:0] rx_data;
  rand int           delay;
  rand int           hold_cycles;

  `uvm_object_utils_begin(sbinit_rsp_rx_transaction)
    `uvm_field_int(rx_valid,    UVM_ALL_ON)
    `uvm_field_int(rx_data,     UVM_ALL_ON)
    `uvm_field_int(delay,       UVM_ALL_ON)
    `uvm_field_int(hold_cycles, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "sbinit_rsp_rx_transaction");
    super.new(name);
    rx_valid    = 0;
    rx_data     = 128'h0;
    delay       = 0;
    hold_cycles = 1;
  endfunction
endclass

`endif
