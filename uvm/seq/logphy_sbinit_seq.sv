`ifndef LOGPHY_SBINIT_SEQ_SV
`define LOGPHY_SBINIT_SEQ_SV

class seq_sbinit_ideal extends logphy_base_seq;
  `uvm_object_utils(seq_sbinit_ideal)

  function new(string name = "seq_sbinit_ideal");
    super.new(name);
  endfunction

  virtual task body();
    logphy_transaction req;
    
    // 1. Kick off FSM
    req = logphy_transaction::type_id::create("req");
    start_item(req);
    req.start_fsm = 1;
    req.delay = 10;
    finish_item(req);

    // 2. Drive the partner 64-UI clocks sequence (acts as compliant partner)
    // Send 10101010 pattern on RX
    req = logphy_transaction::type_id::create("req");
    start_item(req);
    req.start_fsm = 0;
    req.rx_valid = 1;
    req.rx_data = 128'hAAAAAAAAAAAAAAAA_00000000_00000000;
    req.delay = 20; // Some delay to let FSM run
    finish_item(req);
    
    // We could add more checks for Out of Reset messages, but for now we just
    // mimic responding so SBINIT can finish. We simulate receiving the done req
    // and sending the done resp.
    // Done response message placeholder (e.g., bit 7 set for done flag)
    req = logphy_transaction::type_id::create("req");
    start_item(req);
    req.start_fsm = 0;
    req.rx_valid = 1;
    req.rx_data = 128'h00000000_00000000_00000000_00000080; // Placeholder for Done Resp
    req.delay = 50; 
    finish_item(req);

  endtask
endclass

class seq_sbinit_timeout extends logphy_base_seq;
  `uvm_object_utils(seq_sbinit_timeout)

  function new(string name = "seq_sbinit_timeout");
    super.new(name);
  endfunction

  virtual task body();
    logphy_transaction req;
    
    // 1. Kick off FSM
    req = logphy_transaction::type_id::create("req");
    start_item(req);
    req.start_fsm = 1;
    req.delay = 10;
    finish_item(req);

    // 2. Drive NO clock patterns (don't send rx_data)
    // The FSM should timeout and raise fsm_error
    req = logphy_transaction::type_id::create("req");
    start_item(req);
    req.start_fsm = 0;
    req.rx_valid = 0;
    req.delay = 1000; // Large delay to ensure 8ms limit is hit in sim
    finish_item(req);

  endtask
endclass

class seq_sbinit_delayed_ready extends logphy_base_seq;
  `uvm_object_utils(seq_sbinit_delayed_ready)

  function new(string name = "seq_sbinit_delayed_ready");
    super.new(name);
  endfunction

  virtual task body();
    // Implementation placeholder for delaying the `done resp`
  endtask
endclass

class seq_sbinit_collapse_reqs extends logphy_base_seq;
  `uvm_object_utils(seq_sbinit_collapse_reqs)

  function new(string name = "seq_sbinit_collapse_reqs");
    super.new(name);
  endfunction

  virtual task body();
    // Implementation placeholder for collapsing multiple reqs into one resp
  endtask
endclass

`endif
