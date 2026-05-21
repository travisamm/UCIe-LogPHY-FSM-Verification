`ifndef SBINIT_REQ_AGENT_SV
`define SBINIT_REQ_AGENT_SV

// ---------------------------------------------------------------------------
// sbinit_req_agent
// ---------------------------------------------------------------------------
// Active requester agent with two independent drive channels:
//   * rx channel       — partner->DUT data + FSM kick (rx_driver / rx_seqr)
//   * tx-ready channel — back-pressure on the DUT's requester TX
//                        (txready_driver / txready_seqr)
// plus one monitor. The two drivers touch disjoint signals on the same lane,
// so back-pressure can be held/varied concurrently with rx activity.
// ---------------------------------------------------------------------------
class sbinit_req_agent extends uvm_agent;
  `uvm_component_utils(sbinit_req_agent)

  sbinit_req_rx_driver      rx_driver;
  sbinit_req_rx_sequencer   rx_seqr;
  sbinit_req_txready_driver txready_driver;
  sbinit_txready_sequencer  txready_seqr;
  sbinit_req_monitor        monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = sbinit_req_monitor::type_id::create("monitor", this);
    if (get_is_active() == UVM_ACTIVE) begin
      rx_driver      = sbinit_req_rx_driver::type_id::create("rx_driver", this);
      rx_seqr        = sbinit_req_rx_sequencer::type_id::create("rx_seqr", this);
      txready_driver = sbinit_req_txready_driver::type_id::create("txready_driver", this);
      txready_seqr   = sbinit_txready_sequencer::type_id::create("txready_seqr", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE) begin
      rx_driver.seq_item_port.connect(rx_seqr.seq_item_export);
      txready_driver.seq_item_port.connect(txready_seqr.seq_item_export);
    end
  endfunction

endclass

`endif
