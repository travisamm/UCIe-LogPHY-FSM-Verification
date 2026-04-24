`ifndef LOGPHY_TRANSACTION_SV
`define LOGPHY_TRANSACTION_SV

class logphy_transaction extends uvm_sequence_item;
  // RX data (driven to DUT)
  rand logic [127:0] rx_data;
  rand logic         rx_valid;
  rand logic         start_fsm;
  rand int           delay;
  rand int           hold_cycles = 1;
  rand logic [127:0] rsp_rx_data;
  rand logic         rsp_rx_valid;
  logic [127:0]      rsp_tx_data;
  logic              rsp_tx_valid;

  // TX data (observed from DUT)
  logic [127:0]      tx_data;
  logic              tx_valid;
  logic              sbRxTxMode;
  logic              fsm_error;
  logic              fsm_done;

  `uvm_object_utils_begin(logphy_transaction)
    `uvm_field_int(rx_data, UVM_ALL_ON)
    `uvm_field_int(rx_valid, UVM_ALL_ON)
    `uvm_field_int(start_fsm, UVM_ALL_ON)
    `uvm_field_int(delay, UVM_ALL_ON)
    `uvm_field_int(hold_cycles, UVM_ALL_ON)
    `uvm_field_int(rsp_rx_data, UVM_ALL_ON)
    `uvm_field_int(rsp_rx_valid, UVM_ALL_ON)
    `uvm_field_int(rsp_tx_data, UVM_ALL_ON)
    `uvm_field_int(rsp_tx_valid, UVM_ALL_ON)
    `uvm_field_int(tx_data, UVM_ALL_ON)
    `uvm_field_int(tx_valid, UVM_ALL_ON)
    `uvm_field_int(sbRxTxMode, UVM_ALL_ON)
    `uvm_field_int(fsm_error, UVM_ALL_ON)
    `uvm_field_int(fsm_done, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "logphy_transaction");
    super.new(name);
    rx_valid = 0;
    rsp_rx_valid = 0;
    start_fsm = 0;
    rx_data = 0;
    rsp_rx_data = 0;
    rsp_tx_data = 0;
    rsp_tx_valid = 0;
  endfunction

endclass

`endif
