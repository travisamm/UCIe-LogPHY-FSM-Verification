`ifndef LOGPHY_TEST_PKG_SV
`define LOGPHY_TEST_PKG_SV

package logphy_test_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import logphy_env_pkg::*;
  import logphy_seq_pkg::*;

  `include "logphy_base_test.sv"
  `include "logphy_sbinit_tests.sv"

endpackage
`endif
