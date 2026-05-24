`ifndef SBINIT_RSP_AGENT_SV
`define SBINIT_RSP_AGENT_SV

// ---------------------------------------------------------------------------
// sbinit_rsp_agent
// ---------------------------------------------------------------------------
// Active responder agent with two independent drive channels (rx + tx-ready)
// plus one monitor, mirroring sbinit_req_agent on the responder lane.
// ---------------------------------------------------------------------------
class sbinit_rsp_agent extends uvm_agent;
  `uvm_component_utils(sbinit_rsp_agent)

  sbinit_rsp_rx_driver      rx_driver;
  sbinit_rsp_rx_sequencer   rx_seqr;
  sbinit_rsp_txready_driver txready_driver;
  sbinit_txready_sequencer  txready_seqr;
  sbinit_rsp_monitor        monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = sbinit_rsp_monitor::type_id::create("monitor", this);
    if (get_is_active() == UVM_ACTIVE) begin
      rx_driver      = sbinit_rsp_rx_driver::type_id::create("rx_driver", this);
      rx_seqr        = sbinit_rsp_rx_sequencer::type_id::create("rx_seqr", this);
      txready_driver = sbinit_rsp_txready_driver::type_id::create("txready_driver", this);
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
