`ifndef MBTRAIN_ENV_PKG_SV
`define MBTRAIN_ENV_PKG_SV

package mbtrain_env_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import mbtrain_agent_pkg::*;

  `include "../coverage/mbtrain_coverage.sv"
  `include "mbtrain_scoreboard.sv"
  `include "mbtrain_env.sv"

endpackage
`endif
