`ifndef LOGPHY_BASE_SEQ_SV
`define LOGPHY_BASE_SEQ_SV

class logphy_base_seq extends uvm_sequence #(logphy_transaction);
  `uvm_object_utils(logphy_base_seq)

  function new(string name = "logphy_base_seq");
    super.new(name);
  endfunction

  virtual task body();
    logphy_transaction req;
    
    // Kick off FSM
    req = logphy_transaction::type_id::create("req");
    start_item(req);
    req.start_fsm = 1;
    req.delay = 10;
    finish_item(req);

    // Provide some sideband data behavior (acting as responder)
    req = logphy_transaction::type_id::create("req");
    start_item(req);
    req.start_fsm = 0;
    req.rx_valid = 1;
    // We will build more specific sequences later for the tests
    req.rx_data = 128'hAAAAAAAAAAAAAAAA_AAAAAAAAAAAAAAAA; 
    req.delay = 20;
    finish_item(req);

  endtask

endclass
`endif
