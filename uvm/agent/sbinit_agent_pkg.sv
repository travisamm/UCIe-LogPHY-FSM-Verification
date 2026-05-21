`ifndef SBINIT_AGENT_PKG_SV
`define SBINIT_AGENT_PKG_SV

`include "sbinit_msg_pkg.sv"

package sbinit_agent_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import sbinit_msg_pkg::*;

  // Observed/analysis transactions (produced by the monitors, consumed by
  // the scoreboard and coverage).
  `include "sbinit_req_transaction.sv"
  `include "sbinit_rsp_transaction.sv"

  // Drive items: split rx and (shared) tx-ready channels.
  `include "sbinit_req_rx_transaction.sv"
  `include "sbinit_rsp_rx_transaction.sv"
  `include "sbinit_txready_transaction.sv"

  // Sequencers (one per channel; tx-ready sequencer class shared by lanes).
  `include "sbinit_req_rx_sequencer.sv"
  `include "sbinit_rsp_rx_sequencer.sv"
  `include "sbinit_txready_sequencer.sv"

  // Drivers (two per lane: rx + tx-ready).
  `include "sbinit_req_rx_driver.sv"
  `include "sbinit_rsp_rx_driver.sv"
  `include "sbinit_req_txready_driver.sv"
  `include "sbinit_rsp_txready_driver.sv"

  // Monitors and agents.
  `include "sbinit_req_monitor.sv"
  `include "sbinit_rsp_monitor.sv"
  `include "sbinit_req_agent.sv"
  `include "sbinit_rsp_agent.sv"

endpackage

`endif
