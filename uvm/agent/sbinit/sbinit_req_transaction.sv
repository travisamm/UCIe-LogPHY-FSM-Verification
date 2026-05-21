`ifndef SBINIT_REQ_TRANSACTION_SV
`define SBINIT_REQ_TRANSACTION_SV

class sbinit_req_transaction extends uvm_sequence_item;

  // Driven signals (requester side)
  rand logic         fsmCtrl_start;
  rand logic         rx_valid;
  rand logic [127:0] rx_data;
  rand logic         tx_ready;
  rand int           delay;
  rand int           hold_cycles;

  // Observed signals (sampled from DUT)
  logic              tx_valid;
  logic [127:0]      tx_data;
  logic              sbRxTxMode;
  logic              fsm_done;
  logic              fsm_error;

  `uvm_object_utils_begin(sbinit_req_transaction)
    `uvm_field_int(fsmCtrl_start, UVM_ALL_ON)
    `uvm_field_int(rx_valid,      UVM_ALL_ON)
    `uvm_field_int(rx_data,       UVM_ALL_ON)
    `uvm_field_int(tx_ready,      UVM_ALL_ON)
    `uvm_field_int(delay,         UVM_ALL_ON)
    `uvm_field_int(hold_cycles,   UVM_ALL_ON)
    `uvm_field_int(tx_valid,      UVM_ALL_ON)
    `uvm_field_int(tx_data,       UVM_ALL_ON)
    `uvm_field_int(sbRxTxMode,    UVM_ALL_ON)
    `uvm_field_int(fsm_done,      UVM_ALL_ON)
    `uvm_field_int(fsm_error,     UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "sbinit_req_transaction");
    super.new(name);
    fsmCtrl_start = 0;
    rx_valid      = 0;
    rx_data       = 128'h0;
    tx_ready      = 1;
    delay         = 0;
    hold_cycles   = 1;
    tx_valid      = 0;
    tx_data       = 128'h0;
    sbRxTxMode    = 0;
    fsm_done      = 0;
    fsm_error     = 0;
  endfunction

endclass

`endif
