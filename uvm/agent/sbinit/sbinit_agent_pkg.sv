`ifndef SBINIT_AGENT_PKG_SV
`define SBINIT_AGENT_PKG_SV

`include "sbinit_msg_pkg.sv"

package sbinit_agent_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import sbinit_msg_pkg::*;
  import sbinit_event_pkg::*;   // sbinit_event + sbinit_decoder (monitor output)

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

  // Monitors (event producers) and agents. The lane monitors share a
  // vif-agnostic base; the control monitor is instantiated by the env.
  `include "sbinit_lane_monitor_base.sv"
  `include "sbinit_req_monitor.sv"
  `include "sbinit_rsp_monitor.sv"
  `include "sbinit_ctrl_monitor.sv"
  `include "sbinit_req_agent.sv"
  `include "sbinit_rsp_agent.sv"

endpackage

`endif
