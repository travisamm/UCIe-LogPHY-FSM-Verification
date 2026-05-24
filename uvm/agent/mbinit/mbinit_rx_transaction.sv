`ifndef MBINIT_RX_TRANSACTION_SV
`define MBINIT_RX_TRANSACTION_SV

// ---------------------------------------------------------------------------
// mbinit_rx_transaction  (Pass 3)
// ---------------------------------------------------------------------------
// Drive item for a sideband RX channel (partner -> DUT). Shared by the
// requester and responder RX sequencers/drivers - each lane gets its own
// instance via its own driver/sequencer. tx_ready is NOT here: it is currently
// an auto-stub (ready follows valid) folded into the rx driver. A future pass
// can promote tx_ready to its own sequencer/driver for back-pressure tests.
// ---------------------------------------------------------------------------
class mbinit_rx_transaction extends uvm_sequence_item;
  rand logic         rx_valid;
  rand logic [127:0] rx_data;
  rand int           delay;
  rand int           hold_cycles;

  `uvm_object_utils_begin(mbinit_rx_transaction)
    `uvm_field_int(rx_valid,    UVM_ALL_ON)
    `uvm_field_int(rx_data,     UVM_ALL_ON)
    `uvm_field_int(delay,       UVM_ALL_ON)
    `uvm_field_int(hold_cycles, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "mbinit_rx_transaction");
    super.new(name);
    rx_valid    = 0;
    rx_data     = 128'h0;
    delay       = 0;
    hold_cycles = 1;
  endfunction
endclass

`endif
