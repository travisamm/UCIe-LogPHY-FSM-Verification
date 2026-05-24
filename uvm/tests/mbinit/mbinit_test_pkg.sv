`ifndef MBINIT_TEST_PKG_SV
`define MBINIT_TEST_PKG_SV

package mbinit_test_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import mbinit_env_pkg::*;
  import mbinit_seq_pkg::*;
  import mbinit_agent_pkg::*;

  `include "mbinit_base_test.sv"
  `include "mbinit_tests.sv"

endpackage

`endif
