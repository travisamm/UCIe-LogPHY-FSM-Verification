`ifndef SBINIT_ENV_CFG_SV
`define SBINIT_ENV_CFG_SV

class sbinit_env_cfg extends uvm_object;
  `uvm_object_utils(sbinit_env_cfg)

  bit expect_sb01_clock_pattern   = 1;
  bit expect_sb02_rx_sampling     = 1;
  bit expect_sb03_stop_on_detect  = 1;
  bit expect_sb05_mode_transition = 1;
  bit expect_sb06_out_of_reset    = 1;
  bit expect_sb07_done_handshake  = 1;
  bit expect_sb08_ignore_early    = 0;  // set by test_sbinit_early_req
  bit expect_sb09_collapse_reqs   = 0;  // set by test_sbinit_multiple_reqs
  bit expect_fsm_done             = 1;
  bit expect_fsm_error            = 0;

  // Ready/valid data-stability checks. Opt-in per test: the back-pressure
  // scenarios that expose these bugs are specific, and some tests (e.g. the
  // collapse test) legitimately back-pressure a lane without asserting the
  // stability requirement. Each back-pressure test enables only its own.
  bit expect_req_tx_data_stable   = 0;  // set by test_sbinit_req_backpressure
  bit expect_rsp_tx_data_stable   = 0;  // set by test_sbinit_rsp_backpressure

  function new(string name = "sbinit_env_cfg");
    super.new(name);
  endfunction

endclass

`endif
