`ifndef LOGPHY_SBINIT_SEQ_SV
`define LOGPHY_SBINIT_SEQ_SV

class seq_sbinit_ideal extends logphy_base_seq;
  `uvm_object_utils(seq_sbinit_ideal)

  function new(string name = "seq_sbinit_ideal");
    super.new(name);
  endfunction

  virtual task body();
    logphy_transaction req;
    
    // 1 & 2. Kick off FSM and drive the partner 64-UI clocks sequence
    req = logphy_transaction::type_id::create("req");
    start_item(req);
    req.start_fsm = 1;
    req.rx_valid = 1;
    req.rx_data = 128'h00000000_00000000_55555555_55555555;
    req.delay = 10; 
    req.hold_cycles = 5;
    finish_item(req);

    // Wait and send the Out Of Reset Message to advance FSM to state 2
    req = logphy_transaction::type_id::create("req");
    start_item(req);
    req.start_fsm = 0;
    req.rx_valid = 1;
    // Bits[4:0] = 0x12, Bits[21:14] = 0x91 -> 128'h244012
    req.rx_data = 128'h00000000_00000000_00000000_00244012;
    req.delay = 20; 
    req.hold_cycles = 5;
    finish_item(req);

    // Provide Done Resp to finish FSM
    req = logphy_transaction::type_id::create("req");
    start_item(req);
    req.start_fsm = 0;
    req.rx_valid = 1;
    // Bits[4:0] = 0x12, Bits[21:14] = 0x9A, Bits[39:32] = 0x1
    req.rx_data = 128'h00000000_00000000_00000001_00268012;
    req.rsp_rx_valid = 1;
    // SBINIT_DONE_REQ: Bits[4:0] = 0x12, Bits[21:14] = 0x95, Bits[39:32] = 0x1
    req.rsp_rx_data = 128'h00000000_00000000_00000001_00254012;
    req.delay = 20; 
    req.hold_cycles = 5;
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
    
    // 1 & 2. Kick off FSM and drive NO clock patterns
    req = logphy_transaction::type_id::create("req");
    start_item(req);
    req.start_fsm = 1;
    req.rx_valid = 0;
    req.delay = 8500000; // 8.5ms delay to ensure 8ms limit is hit in sim
    finish_item(req);

  endtask
endclass

class seq_sbinit_delayed_ready extends logphy_base_seq;
  `uvm_object_utils(seq_sbinit_delayed_ready)

  function new(string name = "seq_sbinit_delayed_ready");
    super.new(name);
  endfunction

  virtual task body();
    logphy_transaction req;
    
    // 1 & 2. Kick off FSM and drive the partner 64-UI clocks sequence
    req = logphy_transaction::type_id::create("req");
    start_item(req);
    req.start_fsm = 1;
    req.rx_valid = 1;
    req.rx_data = 128'h00000000_00000000_55555555_55555555;
    req.delay = 10; 
    req.hold_cycles = 5;
    finish_item(req);

    // Wait and send the Out Of Reset Message, but DELAY it significantly to verify SB-06
    req = logphy_transaction::type_id::create("req");
    start_item(req);
    req.start_fsm = 0;
    req.rx_valid = 1;
    // Bits[4:0] = 0x12, Bits[21:14] = 0x91 -> 128'h244012
    req.rx_data = 128'h00000000_00000000_00000000_00244012;
    req.delay = 500; // Large delay to ensure DUT continuously outputs its Out of Reset message
    req.hold_cycles = 5;
    finish_item(req);

    // Provide Done Resp to finish FSM
    req = logphy_transaction::type_id::create("req");
    start_item(req);
    req.start_fsm = 0;
    req.rx_valid = 1;
    req.rx_data = 128'h00000000_00000000_00000001_00268012;
    req.rsp_rx_valid = 1;
    req.rsp_rx_data = 128'h00000000_00000000_00000001_00254012;
    req.delay = 20; 
    req.hold_cycles = 5;
    finish_item(req);
  endtask
endclass

class seq_sbinit_early_req extends logphy_base_seq;
  `uvm_object_utils(seq_sbinit_early_req)

  function new(string name = "seq_sbinit_early_req");
    super.new(name);
  endfunction

  virtual task body();
    logphy_transaction req;
    
    // 1. Kick off FSM and drive the partner 64-UI clocks sequence
    req = logphy_transaction::type_id::create("req");
    start_item(req);
    req.start_fsm = 1;
    req.rx_valid = 1;
    req.rx_data = 128'h00000000_00000000_55555555_55555555;
    req.delay = 10; 
    req.hold_cycles = 5;
    finish_item(req);

    // SEND EARLY DONE REQ (SB-08 test)
    // DUT is not ready since TB hasn't sent Out Of Reset yet
    req = logphy_transaction::type_id::create("req");
    start_item(req);
    req.start_fsm = 0;
    req.rsp_rx_valid = 1;
    req.rsp_rx_data = 128'h00000000_00000000_00000001_00254012;
    req.delay = 20; 
    req.hold_cycles = 5;
    finish_item(req);

    // Wait and send the Out Of Reset Message to advance FSM
    req = logphy_transaction::type_id::create("req");
    start_item(req);
    req.start_fsm = 0;
    req.rx_valid = 1;
    req.rx_data = 128'h00000000_00000000_00000000_00244012;
    req.delay = 20; 
    req.hold_cycles = 5;
    finish_item(req);

    // Provide Done Resp to finish FSM (and send DONE REQ again because first one should be ignored)
    req = logphy_transaction::type_id::create("req");
    start_item(req);
    req.start_fsm = 0;
    req.rx_valid = 1;
    req.rx_data = 128'h00000000_00000000_00000001_00268012;
    req.rsp_rx_valid = 1;
    req.rsp_rx_data = 128'h00000000_00000000_00000001_00254012;
    req.delay = 20; 
    req.hold_cycles = 5;
    finish_item(req);
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
