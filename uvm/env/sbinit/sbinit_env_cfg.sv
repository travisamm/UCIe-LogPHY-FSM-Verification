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

  // Ready/valid back-pressure expectations. Opt-in per lane: the back-pressure
  // scenarios that expose the RTL bug are specific, and some tests (e.g. the
  // collapse test) legitimately back-pressure a lane without asserting the
  // stability requirement. Each back-pressure test enables only its own lane.
  //
  // Each flag does double duty (single knob per lane):
  //   1. enables the bound payload-stability SVA on that lane's TX stream
  //      (sb_*_if.stable_chk_en, wired by sbinit_base_test), and
  //   2. enables the scoreboard's semantic offer-under-back-pressure liveness
  //      row for that lane (offered beat must eventually be accepted).
  // Cycle-level payload stability is owned by the SVA, not the scoreboard.
  bit expect_req_tx_data_stable   = 0;  // set by test_sbinit_req_backpressure
  bit expect_rsp_tx_data_stable   = 0;  // set by test_sbinit_rsp_backpressure

  // Malformed-activity escape hatch. The scoreboard hard-fails on UNKNOWN
  // (valid but undecodable) lane words UNLESS they are offered-under-back-
  // pressure beats (the known RTL bug, owned by the SVA). Set this only for
  // tests that intentionally inject malformed traffic.
  bit allow_unknown_events        = 0;

  function new(string name = "sbinit_env_cfg");
    super.new(name);
  endfunction

endclass

`endif
