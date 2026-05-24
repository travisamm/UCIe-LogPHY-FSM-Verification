`ifndef MBINIT_ENV_PKG_SV
`define MBINIT_ENV_PKG_SV

package mbinit_env_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import mbinit_agent_pkg::*;

  // Pass 1 (additive): cfg object declared here so the env package can adopt it
  // in later passes. Not yet consumed by env/scoreboard/driver.
  `include "mbinit_env_cfg.sv"
  `include "mbinit_scoreboard.sv"
  `include "../../coverage/mbinit/mbinit_coverage.sv"
  `include "mbinit_env.sv"

endpackage
`endif
