`ifndef SBINIT_REQ_RX_TRANSACTION_SV
`define SBINIT_REQ_RX_TRANSACTION_SV

// ---------------------------------------------------------------------------
// sbinit_req_rx_transaction
// ---------------------------------------------------------------------------
// Drive item for the requester RX channel: partner -> DUT sideband data plus
// the one-shot FSM kick (fsmCtrl_start). tx_ready is intentionally NOT here;
// back-pressure lives on the independent tx-ready channel
// (sbinit_txready_transaction) so it can be varied concurrently with rx.
// ---------------------------------------------------------------------------
class sbinit_req_rx_transaction extends uvm_sequence_item;
  rand logic         fsmCtrl_start;
  rand logic         rx_valid;
  rand logic [127:0] rx_data;
  rand int           delay;
  rand int           hold_cycles;

  `uvm_object_utils_begin(sbinit_req_rx_transaction)
    `uvm_field_int(fsmCtrl_start, UVM_ALL_ON)
    `uvm_field_int(rx_valid,      UVM_ALL_ON)
    `uvm_field_int(rx_data,       UVM_ALL_ON)
    `uvm_field_int(delay,         UVM_ALL_ON)
    `uvm_field_int(hold_cycles,   UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "sbinit_req_rx_transaction");
    super.new(name);
    fsmCtrl_start = 0;
    rx_valid      = 0;
    rx_data       = 128'h0;
    delay         = 0;
    hold_cycles   = 1;
  endfunction
endclass

`endif
