`ifndef SBINIT_RSP_TRANSACTION_SV
`define SBINIT_RSP_TRANSACTION_SV

class sbinit_rsp_transaction extends uvm_sequence_item;

  // Driven signals (responder side)
  rand logic         rx_valid;
  rand logic [127:0] rx_data;
  rand logic         tx_ready;
  rand int           delay;
  rand int           hold_cycles;

  // Observed signals (sampled from DUT)
  logic              tx_valid;
  logic [127:0]      tx_data;

  `uvm_object_utils_begin(sbinit_rsp_transaction)
    `uvm_field_int(rx_valid,    UVM_ALL_ON)
    `uvm_field_int(rx_data,     UVM_ALL_ON)
    `uvm_field_int(tx_ready,    UVM_ALL_ON)
    `uvm_field_int(delay,       UVM_ALL_ON)
    `uvm_field_int(hold_cycles, UVM_ALL_ON)
    `uvm_field_int(tx_valid,    UVM_ALL_ON)
    `uvm_field_int(tx_data,     UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "sbinit_rsp_transaction");
    super.new(name);
    rx_valid    = 0;
    rx_data     = 128'h0;
    tx_ready    = 1;
    delay       = 0;
    hold_cycles = 1;
    tx_valid    = 0;
    tx_data     = 128'h0;
  endfunction

endclass

`endif
