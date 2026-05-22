`ifndef SBINIT_ENV_PKG_SV
`define SBINIT_ENV_PKG_SV

package sbinit_env_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import sbinit_agent_pkg::*;
  import sbinit_msg_pkg::*;
  import sbinit_event_pkg::*;

  `include "sbinit_env_cfg.sv"
  `include "sbinit_virtual_sequencer.sv"
  `include "../../coverage/sbinit/sbinit_coverage.sv"
  `include "sbinit_scoreboard.sv"
  `include "sbinit_env.sv"

endpackage

`endif
